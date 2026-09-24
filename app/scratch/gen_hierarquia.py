import os

base_path = 'app/lib/src/features'

def create_feature(name, singular, parent_ids, fields, collection_path, has_lote_fields=False):
    os.makedirs(f'{base_path}/{name}/domain', exist_ok=True)
    os.makedirs(f'{base_path}/{name}/data', exist_ok=True)
    os.makedirs(f'{base_path}/{name}/presentation', exist_ok=True)
    os.makedirs(f'{base_path}/{name}/routing', exist_ok=True)

    # Domain
    domain_content = f"""import 'package:json_annotation/json_annotation.dart';

part '{singular}.g.dart';

@JsonSerializable()
class {singular.capitalize()} {{
  final String id;
  final String construtoraId;
"""
    for pid in parent_ids:
        domain_content += f"  final String {pid};\n"
    
    for f_type, f_name in fields:
        domain_content += f"  final {f_type} {f_name};\n"
    
    if has_lote_fields:
        domain_content += """  final String phase;
  final String status;
  final String? responsavelId;
"""
    
    domain_content += f"""  final DateTime createdAt;

  {singular.capitalize()}({{
    required this.id,
    required this.construtoraId,
"""
    for pid in parent_ids:
        domain_content += f"    required this.{pid},\n"
        
    for f_type, f_name in fields:
        domain_content += f"    required this.{f_name},\n"
        
    if has_lote_fields:
        domain_content += """    required this.phase,
    required this.status,
    this.responsavelId,
"""
        
    domain_content += f"""    required this.createdAt,
  }});

  factory {singular.capitalize()}.fromJson(Map<String, dynamic> json) => _${singular.capitalize()}FromJson(json);
  Map<String, dynamic> toJson() => _${singular.capitalize()}ToJson(this);
}}
"""
    with open(f'{base_path}/{name}/domain/{singular}.dart', 'w') as f:
        f.write(domain_content)

    # Data
    path_args = "String construtoraId"
    for pid in parent_ids:
        path_args += f", String {pid}"
        
    col_path_eval = collection_path.replace('{', '${')
        
    data_content = f"""import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/{singular}.dart';

final {singular}RepositoryProvider = Provider<{singular.capitalize()}Repository>((ref) {{
  return {singular.capitalize()}Repository(FirebaseFirestore.instance);
}});

class {singular.capitalize()}Repository {{
  final FirebaseFirestore _firestore;

  {singular.capitalize()}Repository(this._firestore);

  CollectionReference<{singular.capitalize()}> _{name}Ref({path_args}) =>
      _firestore
          .collection('{col_path_eval}')
          .withConverter<{singular.capitalize()}>(
            fromFirestore: (snapshot, _) => {singular.capitalize()}.fromJson(snapshot.data()!),
            toFirestore: ({singular}, _) => {singular}.toJson(),
          );

  Stream<List<{singular.capitalize()}>> watch{name.capitalize()}({path_args}) {{
    return _{name}Ref(construtoraId{', ' + ', '.join(parent_ids) if parent_ids else ''})
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }}

  Future<void> create{singular.capitalize()}({singular.capitalize()} {singular}) async {{
    final docRef = _{name}Ref({singular}.construtoraId{', ' + ', '.join([f'{singular}.{pid}' for pid in parent_ids]) if parent_ids else ''}).doc({singular}.id);
    await docRef.set({singular});
  }}
}}
"""
    with open(f'{base_path}/{name}/data/{singular}_repository.dart', 'w') as f:
        f.write(data_content)
        
    # UI (Basic List Screen)
    ui_content = f"""import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/{singular}_repository.dart';
import '../domain/{singular}.dart';

class {name.capitalize()}ListScreen extends ConsumerWidget {{
  final String construtoraId;
"""
    for pid in parent_ids:
        ui_content += f"  final String {pid};\n"
        
    ui_content += f"""
  const {name.capitalize()}ListScreen({{
    super.key,
    required this.construtoraId,
"""
    for pid in parent_ids:
        ui_content += f"    required this.{pid},\n"
        
    ui_content += f"""  }});

  @override
  Widget build(BuildContext context, WidgetRef ref) {{
    final stream = ref.watch({singular}RepositoryProvider).watch{name.capitalize()}(construtoraId{', ' + ', '.join(parent_ids) if parent_ids else ''});

    return Scaffold(
      appBar: AppBar(title: const Text('{name.capitalize()}')),
      body: StreamBuilder<List<{singular.capitalize()}>>(
        stream: stream,
        builder: (context, snapshot) {{
          if (snapshot.connectionState == ConnectionState.waiting) {{
            return const Center(child: CircularProgressIndicator());
          }}
          if (snapshot.hasError) {{
            return Center(child: Text('Erro: ${{snapshot.error}}'));
          }}
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {{
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                onTap: () {{
                  // Navegar para o próximo nível
                }},
              );
            }},
          );
        }},
      ),
    );
  }}
}}
"""
    with open(f'{base_path}/{name}/presentation/{name}_list_screen.dart', 'w') as f:
        f.write(ui_content)
        
    # Routing
    route_paths = []
    
    routing_content = f"""import 'package:go_router/go_router.dart';
import '../presentation/{name}_list_screen.dart';
import '../../../common_widgets/access_guard.dart';

abstract class {name.capitalize()}Paths {{
"""
    if len(parent_ids) == 0:
        routing_content += f"  static const list = 'loteamentos';\n"
    elif len(parent_ids) == 1:
        routing_content += f"  static const list = 'quadras';\n"
    elif len(parent_ids) == 2:
        routing_content += f"  static const list = 'lotes';\n"
        
    routing_content += f"""}}

List<RouteBase> get {name}Routes => [
      GoRoute(
        path: {name.capitalize()}Paths.list,
        builder: (context, state) {{
          final cId = state.pathParameters['cId']!;
"""
    for pid in parent_ids:
        pid_short = pid.replace('Id', '')
        routing_content += f"          final {pid} = state.pathParameters['{pid}']!;\n"
        
    routing_content += f"""          return AccessGuard(
            construtoraId: cId,
            child: {name.capitalize()}ListScreen(
              construtoraId: cId,
"""
    for pid in parent_ids:
        routing_content += f"              {pid}: {pid},\n"
        
    routing_content += f"""            ),
          );
        }},
      ),
    ];
"""
    with open(f'{base_path}/{name}/routing/{name}_routes.dart', 'w') as f:
        f.write(routing_content)

# Loteamentos
create_feature('loteamentos', 'loteamento', [], [('String', 'name')], 'construtoras/{construtoraId}/loteamentos')
# Quadras
create_feature('quadras', 'quadra', ['loteamentoId'], [('String', 'name')], 'construtoras/{construtoraId}/loteamentos/{loteamentoId}/quadras')
# Lotes (Overwrite)
create_feature('lotes', 'lote', ['loteamentoId', 'quadraId'], [('String', 'name')], 'construtoras/{construtoraId}/loteamentos/{loteamentoId}/quadras/{quadraId}/lotes', True)

print("Gerado.")
