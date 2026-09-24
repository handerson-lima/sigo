import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/compras_parcelas/domain/compra_nf.dart';
import 'package:app/src/features/compras_parcelas/domain/item_compra.dart';
import 'package:app/src/features/compras_parcelas/domain/parcela_compra.dart';

void main() {
  group('Compras Domain & Serialization Tests', () {
    test('Cria, calcula e serializa CompraNf completa com itens e parcelas', () {
      final now = DateTime(2026, 9, 18, 14, 30);
      final vencimento1 = DateTime(2026, 9, 25);
      final vencimento2 = DateTime(2026, 10, 25);

      final compra = CompraNf(
        id: 'compra-001',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        fornecedorId: 'forn-100',
        fornecedorNome: 'Votorantim Cimentos S/A',
        fornecedorDocumento: '01234567000189',
        numeroNf: '00012345',
        serieNf: '1',
        chaveAcessoNf: '35260901234567000189550010000123451000123456',
        dataEmissao: now,
        dataRecebimento: now,
        descricao: 'Compra de cimento para fundações',
        status: StatusCompra.parcial,
        statusRecebimento: StatusRecebimentoCompra.parcial,
        valorItensCents: 350000,
        freteCents: 15000,
        despesasAcessoriasCents: 0,
        descontoCents: 0,
        totalCompraCents: 365000,
        itens: [
          const ItemCompraNf(
            id: 'item-1',
            materialId: 'mat-cimento',
            materialNome: 'Cimento CP II-E-32 (50kg)',
            unidadeMedida: 'sc',
            quantidade: 100.0,
            valorUnitarioCents: 3500,
            valorTotalCents: 350000,
            quantidadeRecebida: 50.0,
          ),
        ],
        parcelas: [
          ParcelaCompra(
            numero: 1,
            valorCents: 182500,
            dataVencimento: vencimento1,
            status: StatusParcelaCompra.pago,
            dataPagamento: now,
            pagoPorUid: 'uid-fin',
            metodoPagamento: MetodoPagamentoCompra.pix,
            comprovanteUrl: 'https://storage.../p1.pdf',
            idempotencyKey: 'idemp-p1',
          ),
          ParcelaCompra(
            numero: 2,
            valorCents: 182500,
            dataVencimento: vencimento2,
            status: StatusParcelaCompra.pendente,
          ),
        ],
        anexoNfUrl: 'https://storage.../danfe.pdf',
        criadoPorUid: 'uid-almoxarife',
        createdAt: now,
        updatedAt: now,
      );

      // Verificação de getters contábeis
      expect(compra.totalCompraCents, 365000);
      expect(compra.totalCompra, 3650.0);
      expect(compra.valorItens, 3500.0);
      expect(compra.frete, 150.0);
      expect(compra.totalPagoCents, 182500);
      expect(compra.totalPago, 1825.0);
      expect(compra.saldoDevedorCents, 182500);
      expect(compra.saldoDevedor, 1825.0);
      expect(compra.isQuitada, isFalse);

      // Verificação de itens
      expect(compra.quantidadeItens, 1);
      expect(compra.itens[0].isTotalmenteRecebido, isFalse);
      expect(compra.itens[0].quantidadePendente, 50.0);
      expect(compra.isTotalmenteRecebido, isFalse);

      // Serialização para Map/JSON
      final json = compra.toJson();
      expect(json['id'], 'compra-001');
      expect(json['fornecedorNome'], 'Votorantim Cimentos S/A');
      expect(json['status'], 'parcial');
      expect(json['statusRecebimento'], 'parcial');
      expect((json['itens'] as List).length, 1);
      expect((json['parcelas'] as List).length, 2);

      // Reconstrução a partir do JSON
      final reconstruida = CompraNf.fromJson(json);
      expect(reconstruida.id, compra.id);
      expect(reconstruida.totalCompraCents, compra.totalCompraCents);
      expect(reconstruida.totalPagoCents, compra.totalPagoCents);
      expect(reconstruida.saldoDevedorCents, compra.saldoDevedorCents);
      expect(reconstruida.parcelas[0].status, StatusParcelaCompra.pago);
      expect(reconstruida.parcelas[0].metodoPagamento, MetodoPagamentoCompra.pix);
      expect(reconstruida.parcelas[1].status, StatusParcelaCompra.pendente);
    });

    test('Identifica compra quitada quando todas as parcelas estão pagas', () {
      final now = DateTime(2026, 9, 18);
      final compra = CompraNf(
        id: 'c-quitada',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        fornecedorId: 'f1',
        fornecedorNome: 'Fornecedor A',
        numeroNf: '101',
        dataEmissao: now,
        valorItensCents: 5000,
        totalCompraCents: 5000,
        status: StatusCompra.pago,
        criadoPorUid: 'uid1',
        createdAt: now,
        updatedAt: now,
        parcelas: [
          ParcelaCompra(
            numero: 1,
            valorCents: 5000,
            dataVencimento: now,
            status: StatusParcelaCompra.pago,
          ),
        ],
      );

      expect(compra.totalPagoCents, 5000);
      expect(compra.saldoDevedorCents, 0);
      expect(compra.isQuitada, isTrue);
      expect(compra.isAtrasada, isFalse);
    });

    test('Identifica compra atrasada quando parcela pendente tem vencimento no passado', () {
      final now = DateTime.now();
      final passado = now.subtract(const Duration(days: 5));

      final compra = CompraNf(
        id: 'c-atrasada',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        fornecedorId: 'f1',
        fornecedorNome: 'Fornecedor B',
        numeroNf: '102',
        dataEmissao: passado,
        valorItensCents: 10000,
        totalCompraCents: 10000,
        status: StatusCompra.aberto,
        criadoPorUid: 'uid1',
        createdAt: passado,
        updatedAt: passado,
        parcelas: [
          ParcelaCompra(
            numero: 1,
            valorCents: 10000,
            dataVencimento: passado,
            status: StatusParcelaCompra.pendente,
          ),
        ],
      );

      expect(compra.isAtrasada, isTrue);
    });

    test('Reconhece item totalmente recebido quando quantidadeRecebida >= quantidade', () {
      const item = ItemCompraNf(
        id: 'i1',
        materialId: 'm1',
        materialNome: 'Areia Média',
        unidadeMedida: 'm³',
        quantidade: 15.0,
        valorUnitarioCents: 12000,
        valorTotalCents: 180000,
        quantidadeRecebida: 15.0,
      );

      expect(item.isTotalmenteRecebido, isTrue);
      expect(item.quantidadePendente, 0.0);
    });
  });
}
