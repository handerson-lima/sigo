void main() {
  final newPath = '/construtoras/c1/loteamentos';
  final uri = Uri.parse(newPath).replace(query: 'q=1', fragment: 'frag');
  print(uri.toString());
}
