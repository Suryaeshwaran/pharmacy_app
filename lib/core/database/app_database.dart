// lib/core/database/app_database.dart

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─── TABLES ──────────────────────────────────────────────────────────────────

class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get genericName => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('piece'))(); // tablet | strip | bottle | tube | piece | ml | gm | capsule | sachet | kit
  RealColumn get mrp => real()(); // Maximum Retail Price
  RealColumn get salePrice => real()(); // Actual selling price
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(10))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get hsnCode => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get billNumber => text()(); // e.g. BILL-2024-001
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get customerName => text().nullable()(); // for walk-in, stored directly
  TextColumn get customerPhone => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get consultationFee => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real()();
  // ── Pharmacy payment ──────────────────────────────────────────────────────
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))(); // cash | online | partial
  RealColumn get cashAmount => real().withDefault(const Constant(0))();
  RealColumn get onlineAmount => real().withDefault(const Constant(0))();
  // ── Consultation fee payment ──────────────────────────────────────────────
  TextColumn get feePaymentMode => text().withDefault(const Constant('cash'))(); // cash | online | partial
  RealColumn get feeCashAmount => real().withDefault(const Constant(0))();
  RealColumn get feeOnlineAmount => real().withDefault(const Constant(0))();
  // ─────────────────────────────────────────────────────────────────────────
  TextColumn get notes => text().nullable()();
  DateTimeColumn get billedAt => dateTime().withDefault(currentDateAndTime)();
}

class BillItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  TextColumn get medicineName => text()(); // snapshot at time of billing
  RealColumn get salePrice => real()(); // snapshot at time of billing
  IntColumn get quantity => integer()();
  RealColumn get totalPrice => real()();
}

// ─── DATABASE ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Medicines, Customers, Bills, BillItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(bills, bills.consultationFee as GeneratedColumn<Object>);
      }
      if (from < 3) {
        await m.addColumn(bills, bills.cashAmount as GeneratedColumn<Object>);
        await m.addColumn(bills, bills.onlineAmount as GeneratedColumn<Object>);
      }
      if (from < 4) {
        await m.addColumn(bills, bills.feePaymentMode as GeneratedColumn<Object>);
        await m.addColumn(bills, bills.feeCashAmount as GeneratedColumn<Object>);
        await m.addColumn(bills, bills.feeOnlineAmount as GeneratedColumn<Object>);
      }
    },
  );

  static QueryExecutor _openDatabase() {
    return driftDatabase(
      name: 'pharmacy_app',
      native: DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  // ─── Medicine Queries ──────────────────────────────────────────────────────

  Stream<List<Medicine>> watchAllMedicines() =>
      (select(medicines)
            ..where((m) => m.isActive.equals(true))
            ..orderBy([(m) => OrderingTerm.asc(m.name)]))
          .watch();

  Future<List<Medicine>> searchMedicines(String query) =>
      (select(medicines)
            ..where((m) =>
                m.name.contains(query) & m.isActive.equals(true))
            ..orderBy([(m) => OrderingTerm.asc(m.name)])
            ..limit(20))
          .get();

  Stream<List<Medicine>> watchLowStockMedicines() => (select(medicines)
        ..where((m) =>
            m.stockQty.isSmallerOrEqual(m.lowStockThreshold) &
            m.isActive.equals(true))
        ..orderBy([(m) => OrderingTerm.asc(m.stockQty)]))
      .watch();

  Stream<List<Medicine>> watchExpiringMedicines() {
    final soon = DateTime.now().add(const Duration(days: 90));
    return (select(medicines)
          ..where((m) =>
              m.expiryDate.isSmallerOrEqualValue(soon) &
              m.expiryDate.isNotNull() &
              m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.expiryDate)]))
        .watch();
  }

  Future<int> insertMedicine(MedicinesCompanion medicine) =>
      into(medicines).insert(medicine);

  Future<bool> updateMedicine(MedicinesCompanion medicine) =>
      update(medicines).replace(medicine);

  Future<void> deductStock(int medicineId, int qty) async {
    await customUpdate(
      'UPDATE medicines SET stock_qty = stock_qty - ?, updated_at = ? WHERE id = ?',
      variables: [Variable(qty), Variable(DateTime.now()), Variable(medicineId)],
      updates: {medicines},
    );
  }

  Future<void> addStock(int medicineId, int qty) async {
    await customUpdate(
      'UPDATE medicines SET stock_qty = stock_qty + ?, updated_at = ? WHERE id = ?',
      variables: [Variable(qty), Variable(DateTime.now()), Variable(medicineId)],
      updates: {medicines},
    );
  }

  Future<Medicine?> getMedicineById(int id) =>
      (select(medicines)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<void> deleteMedicine(int id) async {
    // soft delete — preserves bill history
    await (update(medicines)..where((m) => m.id.equals(id)))
        .write(
          const MedicinesCompanion(
            isActive: Value(false),
          ),
        );
  }

  // ─── Customer Queries ──────────────────────────────────────────────────────

  Future<List<Customer>> searchCustomers(String query) =>
      (select(customers)
            ..where((c) =>
                c.name.contains(query) | c.phone.contains(query))
            ..limit(10))
          .get();

  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);

  // ─── Bill Queries ──────────────────────────────────────────────────────────

  Future<int> insertBill(BillsCompanion bill) =>
      into(bills).insert(bill);

  Future<void> insertBillItems(List<BillItemsCompanion> items) async {
    await batch((b) => b.insertAll(billItems, items));
  }

  Stream<List<Bill>> watchRecentBills({int limit = 50}) =>
      (select(bills)
            ..orderBy([(b) => OrderingTerm.desc(b.billedAt)])
            ..limit(limit))
          .watch();

  Future<List<BillItem>> getBillItems(int billId) =>
      (select(billItems)..where((i) => i.billId.equals(billId))).get();

  Future<Bill?> getBillById(int id) =>
      (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();

  // ─── Edit Bill ─────────────────────────────────────────────────────────────

  /// Updates the bill header row (preserves billNumber and billedAt).
  Future<void> updateBill(BillsCompanion bill) async {
    await (update(bills)..where((b) => b.id.equals(bill.id.value)))
        .write(bill);
  }

  /// Deletes all existing BillItems for [billId] and inserts the new list.
  Future<void> replaceBillItems(
      int billId, List<BillItemsCompanion> newItems) async {
    await transaction(() async {
      await (delete(billItems)..where((i) => i.billId.equals(billId))).go();
      await batch((b) => b.insertAll(billItems, newItems));
    });
  }

  // ─── Delete Bill ───────────────────────────────────────────────────────────

  /// Deletes a bill and its items, then restores stock for all deleted items.
  Future<void> deleteBill(int billId) async {
    await transaction(() async {
      // 1. Fetch items before deleting so we can restore stock
      final items = await getBillItems(billId);

      // 2. Delete bill items first (FK constraint)
      await (delete(billItems)..where((i) => i.billId.equals(billId))).go();

      // 3. Delete the bill
      await (delete(bills)..where((b) => b.id.equals(billId))).go();

      // 4. Restore stock for each item
      for (final item in items) {
        await addStock(item.medicineId, item.quantity);
      }
    });
  }

  // ─── Report Queries ────────────────────────────────────────────────────────

  Future<double> getTotalSales({DateTime? from, DateTime? to}) async {
    final query = select(bills);
    if (from != null) query.where((b) => b.billedAt.isBiggerOrEqualValue(from));
    if (to != null) query.where((b) => b.billedAt.isSmallerOrEqualValue(to));
    final results = await query.get();
    return results.fold<double>(0.0, (sum, b) => sum + b.totalAmount);
  }

  Future<List<Bill>> getBillsByDateRange(DateTime from, DateTime to) =>
      (select(bills)
            ..where((b) =>
                b.billedAt.isBiggerOrEqualValue(from) &
                b.billedAt.isSmallerOrEqualValue(to))
            ..orderBy([(b) => OrderingTerm.desc(b.billedAt)]))
          .get();

  Stream<List<Bill>> watchBillsByDateRange(DateTime from, DateTime to) =>
      (select(bills)
            ..where((b) =>
                b.billedAt.isBiggerOrEqualValue(from) &
                b.billedAt.isSmallerOrEqualValue(to))
            ..orderBy([(b) => OrderingTerm.desc(b.billedAt)]))
          .watch();

  Future<String> generateBillNumber() async {
    final count = await (select(bills)).get();
    final num = (count.length + 1).toString().padLeft(4, '0');
    final now = DateTime.now();
    return 'BILL-${now.year}${now.month.toString().padLeft(2,'0')}-$num';
  }
}