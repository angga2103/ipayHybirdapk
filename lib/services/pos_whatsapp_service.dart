import '../models/pos_shift.dart';
import '../models/pos_cash_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pos_transaction.dart';

/// Layanan Pengiriman Struk Transaksi POS via WhatsApp & Share Digital
class PosWhatsappService {
  PosWhatsappService._internal();
  static final PosWhatsappService instance = PosWhatsappService._internal();

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Menghasilkan format pesan teks struk yang rapi dan elegan untuk WhatsApp
  String generateReceiptText({
    required PosTransaction trx,
    String? storeName,
    String? address,
    String? phone,
  }) {
    final sName = (storeName != null && storeName.trim().isNotEmpty) ? storeName.trim() : 'IPAY POS';
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(trx.dateTime);

    final sb = StringBuffer();
    sb.writeln('🧾 *STRUK PEMBELIAN - ${sName.toUpperCase()}*');
    if (address != null && address.trim().isNotEmpty) {
      sb.writeln(address.trim());
    }
    if (phone != null && phone.trim().isNotEmpty) {
      sb.writeln('Telp: ${phone.trim()}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('No. Nota : ${trx.invoiceNo}');
    sb.writeln('Tanggal  : $dateFormatted');
    sb.writeln('Kasir    : ${trx.cashierName}');
    sb.writeln('--------------------------------');

    for (final it in trx.items) {
      final sub = _currencyFormat.format(it.subtotal);
      sb.writeln('${it.qty}x ${it.productName}');
      sb.writeln('   @ ${_currencyFormat.format(it.soldPrice)} = $sub');
    }

    sb.writeln('--------------------------------');
    sb.writeln('Subtotal  : ${_currencyFormat.format(trx.normalAmount)}');
    if (trx.discountAmount > 0) {
      sb.writeln('Diskon    : -${_currencyFormat.format(trx.discountAmount)}');
    }
    sb.writeln('*TOTAL     : ${_currencyFormat.format(trx.totalAmount)}*');
    sb.writeln('Metode    : ${trx.paymentMethod}');
    sb.writeln('Bayar     : ${_currencyFormat.format(trx.cashPaid)}');
    sb.writeln('Kembalian : ${_currencyFormat.format(trx.changeDue)}');
    sb.writeln('--------------------------------');
    sb.writeln('Terima kasih atas kunjungan Anda!');
    sb.writeln('_Struk digital resmi GarudaTel iPay POS_');

    return sb.toString();
  }

  /// Membuka aplikasi WhatsApp dengan pesan struk terisi otomatis
  Future<bool> sendReceiptViaWhatsApp({
    required PosTransaction trx,
    String? customerPhone,
    String? storeName,
    String? address,
    String? phone,
  }) async {
    try {
      final receiptText = generateReceiptText(
        trx: trx,
        storeName: storeName,
        address: address,
        phone: phone,
      );

      final encodedText = Uri.encodeComponent(receiptText);
      Uri? targetUri;

      if (customerPhone != null && customerPhone.trim().isNotEmpty) {
        String cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.startsWith('0')) {
          cleanPhone = '62${cleanPhone.substring(1)}';
        } else if (cleanPhone.startsWith('8')) {
          cleanPhone = '62$cleanPhone';
        }
        targetUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');
      } else {
        // Tanpa nomor spesifik -> buka pemilih kontak WhatsApp
        targetUri = Uri.parse('whatsapp://send?text=$encodedText');
      }

      if (await canLaunchUrl(targetUri)) {
        return await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback jika WhatsApp tidak terpasang: buka share dialog sistem Android
        await Share.share(receiptText, subject: 'Struk Belanja ${trx.invoiceNo}');
        return true;
      }
    } catch (e) {
      debugPrint('[PosWhatsappService] Error sendReceiptViaWhatsApp: $e');
      try {
        final fallbackText = generateReceiptText(trx: trx, storeName: storeName);
        await Share.share(fallbackText, subject: 'Struk Belanja ${trx.invoiceNo}');
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Format teks laporan rekap tutup kasir (shift) untuk WhatsApp
  String generateShiftReportText({
    required PosShift shift,
    List<PosCashFlow> cashFlows = const [],
    String? storeName,
  }) {
    final sName = (storeName != null && storeName.trim().isNotEmpty) ? storeName.trim() : 'IPAY POS';
    final openedStr = DateFormat('dd/MM/yyyy HH:mm').format(shift.openedAt);
    final closedStr = shift.closedAt != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(shift.closedAt!) 
        : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final diff = shift.cashDifference;
    String diffStatus = 'PAS (SESUAI)';
    if (diff > 0) {
      diffStatus = 'LEBIH +${_currencyFormat.format(diff)}';
    } else if (diff < 0) {
      diffStatus = 'KURANG -${_currencyFormat.format(diff.abs())}';
    }

    final sb = StringBuffer();
    sb.writeln('📊 *LAPORAN REKAP TUTUP KASIR (SHIFT)*');
    sb.writeln('*${sName.toUpperCase()}*');
    sb.writeln('--------------------------------');
    sb.writeln('👤 *Kasir Bertugas* : ${shift.cashierName}');
    sb.writeln('🕒 *Waktu Buka*     : $openedStr WIB');
    sb.writeln('🏁 *Waktu Tutup*    : $closedStr WIB');
    sb.writeln('⏱️ *Durasi Kerja*   : ${shift.formattedDuration}');
    sb.writeln('🧾 *Total Transaksi*: ${shift.totalTransactions} Transaksi');
    sb.writeln('--------------------------------');
    sb.writeln('💵 *1. ARUS UANG TUNAI LACI FISIK*');
    sb.writeln('• Modal Awal Kasir   : ${_currencyFormat.format(shift.startingCash)}');
    sb.writeln('• Penjualan Tunai (+) : ${_currencyFormat.format(shift.totalCashSales)}');
    sb.writeln('• Kas Masuk (+)       : ${_currencyFormat.format(shift.totalCashIn)}');
    sb.writeln('• Kas Keluar (-)      : ${_currencyFormat.format(shift.totalCashOut)}');
    sb.writeln('--------------------------------');
    sb.writeln('*Uang Laci Seharusnya: ${_currencyFormat.format(shift.calculatedExpectedCash)}*');
    sb.writeln('*Uang Fisik Dihitung : ${_currencyFormat.format(shift.actualCash)}*');
    sb.writeln('*HASIL SELISIH       : $diffStatus*');
    sb.writeln('--------------------------------');
    sb.writeln('💳 *2. PENERIMAAN NON-TUNAI*');
    sb.writeln('• Penjualan QRIS (Bank)   : ${_currencyFormat.format(shift.totalQrisSales)}');
    sb.writeln('• Penjualan Kasbon (Piutang): ${_currencyFormat.format(shift.totalDebtSales)}');
    sb.writeln('--------------------------------');
    sb.writeln('📈 *3. TOTAL OMSET PENJUALAN*');
    sb.writeln('*TOTAL OMSET KOTOR : ${_currencyFormat.format(shift.totalSales)}*');
    if (cashFlows.isNotEmpty) {
      sb.writeln('--------------------------------');
      sb.writeln('📑 *RINCIAN KAS MASUK / KELUAR*');
      for (final flow in cashFlows) {
        final sign = flow.isCashIn ? '[+]' : '[-]';
        sb.writeln('$sign ${flow.category} (${flow.note ?? "-"}): ${_currencyFormat.format(flow.amount)}');
      }
    }
    if (shift.notes != null && shift.notes!.trim().isNotEmpty) {
      sb.writeln('--------------------------------');
      sb.writeln('📝 *Catatan Kasir* : ${shift.notes!.trim()}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('_Laporan otomatis Sistem Kasir Offline GarudaTel iPay_');

    return sb.toString();
  }

  /// Membuka aplikasi WhatsApp dengan laporan tutup shift terisi otomatis
  Future<bool> sendShiftReportViaWhatsApp({
    required PosShift shift,
    List<PosCashFlow> cashFlows = const [],
    String? targetPhone,
    String? storeName,
  }) async {
    try {
      final reportText = generateShiftReportText(
        shift: shift,
        cashFlows: cashFlows,
        storeName: storeName,
      );

      final encodedText = Uri.encodeComponent(reportText);
      Uri targetUri;

      if (targetPhone != null && targetPhone.trim().isNotEmpty) {
        String cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.startsWith('0')) {
          cleanPhone = '62${cleanPhone.substring(1)}';
        } else if (cleanPhone.startsWith('8')) {
          cleanPhone = '62$cleanPhone';
        }
        targetUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');
      } else {
        targetUri = Uri.parse('whatsapp://send?text=$encodedText');
      }

      if (await canLaunchUrl(targetUri)) {
        return await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(reportText, subject: 'Laporan Tutup Shift Kasir ${shift.cashierName}');
        return true;
      }
    } catch (e) {
      debugPrint('[PosWhatsappService] Error sendShiftReportViaWhatsApp: $e');
      try {
        final fallback = generateShiftReportText(shift: shift, storeName: storeName);
        await Share.share(fallback, subject: 'Laporan Tutup Shift Kasir');
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
