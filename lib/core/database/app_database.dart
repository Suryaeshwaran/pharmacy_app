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
  TextColumn get unit => text().withDefault(const Constant('piece'))();
  RealColumn get mrp => real()();
  RealColumn get salePrice => real()();
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

class PatientMaster extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pid => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get ph1 => text().nullable()();
  TextColumn get ph2 => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tracks patients queued to visit today. Cleared on billing or manual dismiss.
class VisitQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pid => text()();
  TextColumn get patientName => text()();
  TextColumn get patientPhone => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stores pharmacy registration and contact details (single row, id = 1).
class PharmacyInfo extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get gstn => text().nullable()();
  TextColumn get regn => text().nullable()();
}

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get billNumber => text()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get patientId => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get consultationFee => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  RealColumn get cashAmount => real().withDefault(const Constant(0))();
  RealColumn get onlineAmount => real().withDefault(const Constant(0))();
  TextColumn get feePaymentMode => text().withDefault(const Constant('cash'))();
  RealColumn get feeCashAmount => real().withDefault(const Constant(0))();
  RealColumn get feeOnlineAmount => real().withDefault(const Constant(0))();
  RealColumn get collectionAmount => real().withDefault(const Constant(0))();
  RealColumn get balanceAmount => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get billedAt => dateTime().withDefault(currentDateAndTime)();
}

class BillItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  TextColumn get medicineName => text()();
  RealColumn get salePrice => real()();
  IntColumn get quantity => integer()();
  RealColumn get totalPrice => real()();
}

// ─── DATABASE ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Medicines, Customers, PatientMaster, VisitQueue, PharmacyInfo, Bills, BillItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 9;

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
      if (from < 5) {
        await m.createTable(patientMaster);
      }
      if (from < 6) {
        await m.createTable(visitQueue);
      }
      if (from < 7) {
        await m.createTable(pharmacyInfo);
      }
      if (from < 8) {
        await m.addColumn(bills, bills.collectionAmount as GeneratedColumn<Object>);
        await m.addColumn(bills, bills.balanceAmount as GeneratedColumn<Object>);
      }
      if (from < 9) {
        await m.addColumn(bills, bills.patientId as GeneratedColumn<Object>);
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
            ..where((m) => m.name.contains(query) & m.isActive.equals(true))
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
    await (update(medicines)..where((m) => m.id.equals(id)))
        .write(const MedicinesCompanion(isActive: Value(false)));
  }

  // ─── Customer Queries ──────────────────────────────────────────────────────

  Future<List<Customer>> searchCustomers(String query) =>
      (select(customers)
            ..where((c) => c.name.contains(query) | c.phone.contains(query))
            ..limit(10))
          .get();

  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);

  // ─── Patient Queries ───────────────────────────────────────────────────────

  /// Search by PID only
  Future<List<PatientMasterData>> searchPatientsByPid(String query) =>
      (select(patientMaster)
            ..where((p) => p.pid.contains(query))
            ..orderBy([(p) => OrderingTerm.asc(p.name)])
            ..limit(20))
          .get();

  /// Search by Name only
  Future<List<PatientMasterData>> searchPatientsByName(String query) =>
      (select(patientMaster)
            ..where((p) => p.name.contains(query))
            ..orderBy([(p) => OrderingTerm.asc(p.name)])
            ..limit(20))
          .get();

  /// Search by Phone — checks both ph1 and ph2
  Future<List<PatientMasterData>> searchPatientsByPhone(String query) =>
      (select(patientMaster)
            ..where((p) => p.ph1.contains(query) | p.ph2.contains(query))
            ..orderBy([(p) => OrderingTerm.asc(p.name)])
            ..limit(20))
          .get();

  Future<PatientMasterData?> getPatientByPid(String pid) =>
      (select(patientMaster)..where((p) => p.pid.equals(pid)))
          .getSingleOrNull();

  Future<int> insertPatient(PatientMasterCompanion patient) =>
      into(patientMaster).insert(patient);

  Future<bool> updatePatient(PatientMasterCompanion patient) =>
      update(patientMaster).replace(patient);

  Future<void> deletePatient(int id) =>
      (delete(patientMaster)..where((p) => p.id.equals(id))).go();

  Future<int> getTotalPatientCount() async {
    final rows = await select(patientMaster).get();
    return rows.length;
  }

  /// Live count of patients — updates automatically as patients are
  /// added, edited, or deleted (used by the "Total Patients" chip).
  Stream<int> watchPatientCount() =>
      select(patientMaster).watch().map((rows) => rows.length);

  // ─── Visit Queue Queries ───────────────────────────────────────────────────

  /// Watch all entries in today's visit queue, ordered by time added.
  Stream<List<VisitQueueData>> watchVisitQueue() =>
      (select(visitQueue)..orderBy([(v) => OrderingTerm.asc(v.addedAt)]))
          .watch();

  /// Add a patient to today's visit queue.
  Future<int> addToVisitQueue(VisitQueueCompanion entry) =>
      into(visitQueue).insert(entry);

  /// Check if a patient (by pid) is already in the queue.
  Future<bool> isInVisitQueue(String pid) async {
    final row = await (select(visitQueue)..where((v) => v.pid.equals(pid)))
        .getSingleOrNull();
    return row != null;
  }

  /// Remove a single entry from the visit queue by row id.
  Future<void> removeFromVisitQueue(int id) =>
      (delete(visitQueue)..where((v) => v.id.equals(id))).go();

  /// Remove by pid — called after billing is completed.
  Future<void> removeFromVisitQueueByPid(String pid) =>
      (delete(visitQueue)..where((v) => v.pid.equals(pid))).go();

  /// Delete all queue entries added before today (midnight local time).
  /// Called when the Patient screen loads to clear stale yesterday/old entries.
  Future<void> purgeStaleQueueEntries() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    await (delete(visitQueue)
          ..where((v) => v.addedAt.isSmallerThanValue(todayMidnight)))
        .go();
  }

  // ─── Pharmacy Info Queries ─────────────────────────────────────────────────

  /// Returns the single pharmacy info row, or null if not yet set up.
  Future<PharmacyInfoData?> getPharmacyInfo() =>
      (select(pharmacyInfo)..where((p) => p.id.equals(1))).getSingleOrNull();

  /// Insert or replace the pharmacy info row (always uses id = 1).
  Future<void> upsertPharmacyInfo(PharmacyInfoCompanion info) async {
    await into(pharmacyInfo).insertOnConflictUpdate(
      info.copyWith(id: const Value(1)),
    );
  }

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

  Future<void> updateBill(BillsCompanion bill) async {
    await (update(bills)..where((b) => b.id.equals(bill.id.value))).write(bill);
  }

  Future<void> replaceBillItems(
      int billId, List<BillItemsCompanion> newItems) async {
    await transaction(() async {
      await (delete(billItems)..where((i) => i.billId.equals(billId))).go();
      await batch((b) => b.insertAll(billItems, newItems));
    });
  }

  // ─── Delete Bill ───────────────────────────────────────────────────────────

  Future<void> deleteBill(int billId) async {
    await transaction(() async {
      final items = await getBillItems(billId);
      await (delete(billItems)..where((i) => i.billId.equals(billId))).go();
      await (delete(bills)..where((b) => b.id.equals(billId))).go();
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
    return 'BILL-${now.year}${now.month.toString().padLeft(2, '0')}-$num';
  }

  // ─── Maintenance / Data Cleanup ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCleanupMonths() async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - 3, 1);
    final cutoffSeconds = cutoff.millisecondsSinceEpoch ~/ 1000;

    final rows = await customSelect(
      '''
      SELECT
        strftime('%Y', datetime(billed_at, 'unixepoch', 'localtime')) AS yr,
        strftime('%m', datetime(billed_at, 'unixepoch', 'localtime')) AS mo,
        COUNT(*) AS bill_count
      FROM bills
      WHERE billed_at < ?
      GROUP BY yr, mo
      ORDER BY yr DESC, mo DESC
      ''',
      variables: [Variable<int>(cutoffSeconds)],
      readsFrom: {bills},
    ).get();

    return rows.map((r) => {
      'year': int.parse(r.read<String>('yr')),
      'month': int.parse(r.read<String>('mo')),
      'count': r.read<int>('bill_count'),
    }).toList();
  }

  Future<int> deleteMonthData(int year, int month) async {
    final from = DateTime(year, month);
    final to = DateTime(year, month + 1);

    int deleted = 0;
    await transaction(() async {
      final monthBills = await (select(bills)
            ..where((b) =>
                b.billedAt.isBiggerOrEqualValue(from) &
                b.billedAt.isSmallerThanValue(to)))
          .get();

      if (monthBills.isEmpty) return;
      deleted = monthBills.length;
      final ids = monthBills.map((b) => b.id).toList();

      for (final id in ids) {
        await (delete(billItems)..where((i) => i.billId.equals(id))).go();
      }

      await (delete(bills)
            ..where((b) =>
                b.billedAt.isBiggerOrEqualValue(from) &
                b.billedAt.isSmallerThanValue(to)))
          .go();
    });

    await customStatement('VACUUM');
    return deleted;
  }
}