import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/scheme.dart';
import '../models/scheme_row.dart';
import '../core/utils/debounce.dart';
import '../services/scheme_sync_service.dart';

enum SaveStatus { saved, saving, unsaved, error }

class SchemeEditorProvider extends ChangeNotifier {
  final _syncService = SchemeSyncService.instance;
  final _uuid = const Uuid();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 600));

  Scheme? _scheme;
  Scheme? get scheme => _scheme;

  List<SchemeRow> _rows = [];
  List<SchemeRow> get rows => _rows;

  SaveStatus _saveStatus = SaveStatus.saved;
  SaveStatus get saveStatus => _saveStatus;

  bool _isTableView = false;
  bool get isTableView => _isTableView;

  int _selectedRowIndex = 0;
  int get selectedRowIndex => _selectedRowIndex;

  void setScheme(Scheme scheme) {
    _scheme = scheme;
    _rows = List<SchemeRow>.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));
    _saveStatus = SaveStatus.saved;
    _selectedRowIndex = 0;
    notifyListeners();
  }

  void toggleViewMode() {
    _isTableView = !_isTableView;
    notifyListeners();
  }

  void selectRowIndex(int index) {
    if (index >= 0 && index < _rows.length) {
      _selectedRowIndex = index;
      notifyListeners();
    }
  }

  /// Update an existing row
  void updateRow(int index, SchemeRow updatedRow) {
    if (index < 0 || index >= _rows.length) return;
    _rows[index] = updatedRow;
    _saveStatus = SaveStatus.unsaved;
    notifyListeners();

    _triggerAutosave(updatedRow);
  }

  /// Update reflections text for a row
  void updateReflections(int index, String text) {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    final updated = row.copyWith(reflections: text);
    _rows[index] = updated;
    _saveStatus = SaveStatus.unsaved;
    notifyListeners();

    _triggerAutosave(updated);
  }

  /// Insert a blank or cloned lesson row below the specified index
  void insertRowBelow(int index) {
    if (index < 0 || index >= _rows.length) return;
    final prevRow = _rows[index];
    final newRow = SchemeRow(
      id: _uuid.v4(),
      schemeId: _scheme?.id,
      weekNumber: prevRow.weekNumber,
      lessonNumber: prevRow.lessonNumber + 1,
      strandName: prevRow.strandName,
      subStrandName: prevRow.subStrandName,
      learningOutcomes: List.from(prevRow.learningOutcomes),
      keyInquiryQuestions: List.from(prevRow.keyInquiryQuestions),
      learningExperiences: List.from(prevRow.learningExperiences),
      learningResources: List.from(prevRow.learningResources),
      assessmentMethods: List.from(prevRow.assessmentMethods),
      reflections: '',
      position: prevRow.position + 1,
    );

    _rows.insert(index + 1, newRow);
    _reindexPositions();
    _saveStatus = SaveStatus.unsaved;
    _selectedRowIndex = index + 1;
    notifyListeners();

    _triggerAutosave(newRow);
  }

  /// Delete a row
  void deleteRow(int index) {
    if (_rows.length <= 1 || index < 0 || index >= _rows.length) return;
    _rows.removeAt(index);
    _reindexPositions();
    if (_selectedRowIndex >= _rows.length) {
      _selectedRowIndex = _rows.length - 1;
    }
    _saveStatus = SaveStatus.unsaved;
    notifyListeners();

    // Trigger full scheme autosave
    _triggerFullAutosave();
  }

  /// Move a row up or down
  void moveRow(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _rows.length || newIndex < 0 || newIndex >= _rows.length) return;
    final row = _rows.removeAt(oldIndex);
    _rows.insert(newIndex, row);
    _reindexPositions();
    _selectedRowIndex = newIndex;
    _saveStatus = SaveStatus.unsaved;
    notifyListeners();

    _triggerFullAutosave();
  }

  void _reindexPositions() {
    for (int i = 0; i < _rows.length; i++) {
      _rows[i].position = i;
    }
  }

  void _triggerAutosave(SchemeRow row) {
    _debouncer.run(() async {
      if (_scheme == null) return;
      _saveStatus = SaveStatus.saving;
      notifyListeners();

      final isGuest = _scheme!.id.startsWith('guest-') || _scheme!.userId == null;
      final success = await _syncService.saveRow(
        schemeId: _scheme!.id,
        row: row,
        isGuest: isGuest,
      );

      _saveStatus = success ? SaveStatus.saved : SaveStatus.error;
      notifyListeners();
    });
  }

  void _triggerFullAutosave() {
    _debouncer.run(() async {
      if (_scheme == null) return;
      _saveStatus = SaveStatus.saving;
      notifyListeners();

      final isGuest = _scheme!.id.startsWith('guest-') || _scheme!.userId == null;
      bool allSuccess = true;
      for (final r in _rows) {
        final success = await _syncService.saveRow(
          schemeId: _scheme!.id,
          row: r,
          isGuest: isGuest,
        );
        if (!success) allSuccess = false;
      }

      _saveStatus = allSuccess ? SaveStatus.saved : SaveStatus.error;
      notifyListeners();
    });
  }

  /// Returns current scheme snapshot with live modified rows
  Scheme get updatedScheme {
    if (_scheme == null) throw StateError('Scheme is null');
    return _scheme!.copyWith(rows: _rows);
  }
}
