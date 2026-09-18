enum ChamadaStatus {
  emAberto('em_aberto', 'Em Aberto'),
  fechada('fechada', 'Fechada'),
  retificada('retificada', 'Retificada');

  final String value;
  final String label;

  const ChamadaStatus(this.value, this.label);

  static ChamadaStatus fromValue(String? val) {
    if (val == 'fechada' || val == 'confirmada') return ChamadaStatus.fechada;
    if (val == 'retificada') return ChamadaStatus.retificada;
    return ChamadaStatus.emAberto;
  }
}
