import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../almoxarifado/domain/movimentacao.dart';
import '../../despesas_adm/domain/despesa_adm.dart';
import '../../lotes/domain/lote.dart';
import '../../rh/domain/chamada_diaria.dart';
import '../domain/custo_lote_consolidado.dart';
import '../domain/rateio_indireto_math.dart';

final custos360RepositoryProvider = Provider<Custos360Repository>((ref) {
  return Custos360Repository(FirebaseFirestore.instance);
});

class Custos360Repository {
  final FirebaseFirestore _firestore;

  Custos360Repository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _obrasRef(String construtoraId) =>
      _firestore.collection('construtoras').doc(construtoraId).collection('obras');

  CollectionReference<Map<String, dynamic>> _lotesRef(
          String construtoraId, String obraId) =>
      _obrasRef(construtoraId).doc(obraId).collection('lotes');

  CollectionReference<Map<String, dynamic>> _despesasRef(
          String construtoraId, String obraId) =>
      _obrasRef(construtoraId).doc(obraId).collection('despesas_adm');

  CollectionReference<Map<String, dynamic>> _chamadasRef(
          String construtoraId, String obraId) =>
      _obrasRef(construtoraId).doc(obraId).collection('chamadas');

  DocumentReference<Map<String, dynamic>> _resumoObraDoc(
          String construtoraId, String obraId) =>
      _obrasRef(construtoraId)
          .doc(obraId)
          .collection('resumo_custos')
          .doc('consolidado');

  DocumentReference<Map<String, dynamic>> _resumoLoteDoc(
          String construtoraId, String obraId, String loteId) =>
      _lotesRef(construtoraId, obraId)
          .doc(loteId)
          .collection('resumo_custos')
          .doc('consolidado');

  /// Observa em tempo real a consolidação matricial dos custos da obra e seus lotes
  Stream<ResumoCustosObra> watchResumoObra(String construtoraId, String obraId) {
    return _lotesRef(construtoraId, obraId).snapshots().asyncMap((lotesSnap) async {
      final lotes = lotesSnap.docs.map((doc) => Lote.fromJson(doc.data())).toList();
      return await consolidarCustos(construtoraId, obraId, lotes);
    });
  }

  /// Calcula a consolidação dos 4 cubos em tempo real e persiste snapshot em background
  Future<ResumoCustosObra> consolidarCustos(
    String construtoraId,
    String obraId,
    List<Lote> lotes,
  ) async {
    // 1. Obter Despesas Administrativas da Obra
    final despesasSnap = await _despesasRef(construtoraId, obraId).get();
    final despesas = despesasSnap.docs
        .map((d) => DespesaAdm.fromJson(d.data()))
        .where((d) => d.status != StatusDespesaAdm.cancelado)
        .toList();

    // 2. Obter Chamadas Diárias de RH da Obra
    final chamadasSnap = await _chamadasRef(construtoraId, obraId).get();
    final chamadas = chamadasSnap.docs
        .map((d) => ChamadaDiaria.fromMap(d.data()))
        .toList();

    // 3. Obter Movimentações de Saída de Almoxarifado da Obra
    List<Movimentacao> movimentacoes = [];
    try {
      final movSnap = await _firestore
          .collectionGroup('movimentacoes')
          .where('obraId', isEqualTo: obraId)
          .get();
      movimentacoes = movSnap.docs
          .map((d) => Movimentacao.fromJson(d.data()))
          .where((m) => m.reversedBy == null)
          .toList();
    } catch (_) {
      // Caso o índice collectionGroup esteja pendente ou indisponível
      movimentacoes = [];
    }

    // Estruturas de agregação por Lote
    final materiaisMap = <String, int>{for (final l in lotes) l.id: 0};
    final moMap = <String, int>{for (final l in lotes) l.id: 0};
    final despesasDiretasMap = <String, int>{for (final l in lotes) l.id: 0};
    var totalDespesasIndiretasCents = 0;

    // Agregação de Materiais
    for (final mov in movimentacoes) {
      if (mov.apropriacaoLote == true &&
          mov.loteId != null &&
          materiaisMap.containsKey(mov.loteId)) {
        final custo = mov.custoTotalCentavos ??
            (mov.valorItensCentavos ?? 0) +
                (mov.freteCentavos ?? 0) +
                (mov.despesasCentavos ?? 0) -
                (mov.descontoCentavos ?? 0);

        if (mov.commandType == 'estorno') {
          materiaisMap[mov.loteId!] = (materiaisMap[mov.loteId!] ?? 0) - custo;
        } else {
          materiaisMap[mov.loteId!] = (materiaisMap[mov.loteId!] ?? 0) + custo;
        }
      }
    }

    // Agregação de Mão de Obra
    for (final chamada in chamadas) {
      for (final lotSummary in chamada.lotCostSummaries) {
        if (moMap.containsKey(lotSummary.lotId)) {
          moMap[lotSummary.lotId] =
              (moMap[lotSummary.lotId] ?? 0) + lotSummary.totalCostCents;
        }
      }
    }

    // Agregação de Despesas Administrativas (Diretas e Indiretas)
    for (final desp in despesas) {
      if (desp.loteId != null &&
          desp.loteId!.isNotEmpty &&
          despesasDiretasMap.containsKey(desp.loteId)) {
        despesasDiretasMap[desp.loteId!] =
            (despesasDiretasMap[desp.loteId!] ?? 0) + desp.valorTotalCents;
      } else {
        totalDespesasIndiretasCents += desp.valorTotalCents;
      }
    }

    // Rateio Indireto Matemático sem resíduos de centavos
    final lotesIds = lotes.map((l) => l.id).toList();
    final rateioMap = RateioIndiretoMath.distribuir(
      totalDespesasIndiretasCents: totalDespesasIndiretasCents,
      lotesIds: lotesIds,
    );

    // Ler orçamentos persistidos para cada lote
    final lotesCustos = <CustoLoteConsolidado>[];
    var totalGeralMat = 0;
    var totalGeralMo = 0;
    var totalGeralDd = 0;
    var orcamentoTotalPrevisto = 0;

    for (final lote in lotes) {
      final mat = materiaisMap[lote.id] ?? 0;
      final mo = moMap[lote.id] ?? 0;
      final dd = despesasDiretasMap[lote.id] ?? 0;
      final ri = rateioMap[lote.id] ?? 0;

      totalGeralMat += mat;
      totalGeralMo += mo;
      totalGeralDd += dd;

      var orcamentoLote = 0;
      try {
        final resumoLoteDoc =
            await _resumoLoteDoc(construtoraId, obraId, lote.id).get();
        if (resumoLoteDoc.exists && resumoLoteDoc.data() != null) {
          orcamentoLote =
              (resumoLoteDoc.data()!['orcamentoPrevistoCents'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      orcamentoTotalPrevisto += orcamentoLote;

      final consolidado = CustoLoteConsolidado(
        loteId: lote.id,
        loteNome: lote.name,
        materiaisCents: mat,
        maoDeObraCents: mo,
        despesasDiretasCents: dd,
        rateioIndiretoCents: ri,
        orcamentoPrevistoCents: orcamentoLote,
      );

      lotesCustos.add(consolidado);

      // Persiste em background o snapshot do lote
      _resumoLoteDoc(construtoraId, obraId, lote.id)
          .set(consolidado.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    final totalGeral = totalGeralMat + totalGeralMo + totalGeralDd + totalDespesasIndiretasCents;

    final resumoObra = ResumoCustosObra(
      obraId: obraId,
      totalGeralCents: totalGeral,
      totalMateriaisCents: totalGeralMat,
      totalMaoDeObraCents: totalGeralMo,
      totalDespesasDiretasCents: totalGeralDd,
      totalDespesasIndiretasCents: totalDespesasIndiretasCents,
      orcamentoTotalPrevistoCents: orcamentoTotalPrevisto,
      lotesCustos: lotesCustos,
    );

    // Persiste snapshot consolidado da obra
    _resumoObraDoc(construtoraId, obraId)
        .set(resumoObra.toMap(), SetOptions(merge: true))
        .catchError((_) {});

    return resumoObra;
  }

  /// Busca o extrato detalhado de todos os lançamentos que compõem os 4 cubos de um lote
  Future<List<ExtratoItemCusto>> buscarExtratoLote({
    required String construtoraId,
    required String obraId,
    required String loteId,
  }) async {
    final itens = <ExtratoItemCusto>[];

    // 1. Materiais
    try {
      final movSnap = await _firestore
          .collectionGroup('movimentacoes')
          .where('obraId', isEqualTo: obraId)
          .where('loteId', isEqualTo: loteId)
          .get();

      for (final doc in movSnap.docs) {
        final mov = Movimentacao.fromJson(doc.data());
        if (mov.reversedBy != null || mov.apropriacaoLote != true) continue;

        final isEstorno = mov.commandType == 'estorno';
        final val = mov.custoTotalCentavos ?? (mov.valorItensCentavos ?? 0);
        itens.add(ExtratoItemCusto(
          id: mov.id,
          cubo: CuboCusto.material,
          descricao: isEstorno
              ? 'Estorno Material: ${mov.observacao ?? mov.materialId}'
              : 'Saída Material: ${mov.observacao ?? mov.materialId}',
          data: mov.date,
          valorCents: isEstorno ? -val : val,
          documentoReferencia: mov.nfNumber,
          responsavelNome: mov.solicitante,
        ));
      }
    } catch (_) {}

    // 2. Mão de Obra
    final chamadasSnap = await _chamadasRef(construtoraId, obraId).get();
    for (final doc in chamadasSnap.docs) {
      final chamada = ChamadaDiaria.fromMap(doc.data());
      if (chamada.status == 'cancelada') continue;
      for (final lotSummary in chamada.lotCostSummaries) {
        if (lotSummary.lotId == loteId && lotSummary.totalCostCents > 0) {
          itens.add(ExtratoItemCusto(
            id: '${chamada.id}_${lotSummary.lotId}',
            cubo: CuboCusto.maoDeObra,
            descricao: 'Equipe diária (${lotSummary.workerCount} colaboradores)',
            data: DateTime.tryParse(chamada.date) ?? DateTime.now(),
            valorCents: lotSummary.totalCostCents,
            documentoReferencia: 'Chamada #${chamada.id.substring(0, chamada.id.length > 8 ? 8 : chamada.id.length)}',
            responsavelNome: chamada.createdByUid,
          ));
        }
      }
    }

    // 3. Despesas Diretas
    final despesasSnap = await _despesasRef(construtoraId, obraId).get();
    for (final doc in despesasSnap.docs) {
      final desp = DespesaAdm.fromJson(doc.data());
      if (desp.status != StatusDespesaAdm.cancelado && desp.loteId == loteId) {
        itens.add(ExtratoItemCusto(
          id: desp.id,
          cubo: CuboCusto.despesaDireta,
          descricao: '${desp.categoria.label}: ${desp.descricao}',
          data: desp.dataVencimento,
          valorCents: desp.valorTotalCents,
          documentoReferencia: desp.comprovanteNome ?? desp.id,
          responsavelNome: desp.responsavelId,
        ));
      }
    }

    // 4. Rateio Indireto (Lançamento sintético consolidado do lote)
    try {
      final resumoLoteDoc = await _resumoLoteDoc(construtoraId, obraId, loteId).get();
      if (resumoLoteDoc.exists && resumoLoteDoc.data() != null) {
        final rateioCents = (resumoLoteDoc.data()!['rateioIndiretoCents'] as num?)?.toInt() ?? 0;
        if (rateioCents > 0) {
          itens.add(ExtratoItemCusto(
            id: 'rateio_indireto_$loteId',
            cubo: CuboCusto.rateioIndireto,
            descricao: 'Cota-parte das Despesas Gerais da Obra (Rateio Indireto)',
            data: DateTime.now(),
            valorCents: rateioCents,
            documentoReferencia: 'Rateio Algébrico AD-7',
            responsavelNome: 'Sistema SIGO',
          ));
        }
      }
    } catch (_) {}

    // Ordenar itens do mais recente para o mais antigo
    itens.sort((a, b) => b.data.compareTo(a.data));
    return itens;
  }

  /// Atualiza o orçamento previsto para um lote
  Future<void> atualizarOrcamentoLote({
    required String construtoraId,
    required String obraId,
    required String loteId,
    required int orcamentoPrevistoCents,
  }) async {
    await _resumoLoteDoc(construtoraId, obraId, loteId).set({
      'orcamentoPrevistoCents': orcamentoPrevistoCents,
      'ultimaAtualizacao': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Também espelha em lote para conveniência
    await _lotesRef(construtoraId, obraId).doc(loteId).set({
      'orcamentoPrevistoCents': orcamentoPrevistoCents,
    }, SetOptions(merge: true));
  }
}
