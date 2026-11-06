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
}
