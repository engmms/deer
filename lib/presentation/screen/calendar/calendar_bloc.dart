import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:deer/domain/entity/todo_entity.dart';
import 'package:deer/presentation/app.dart';
import 'package:deer/utils/string_utils.dart';
import 'package:rxdart/rxdart.dart';

import 'calendar_actions.dart';
import 'calendar_state.dart';

class CalendarBloc {
  Sink get actions => _actions;
  final _actions = StreamController();

  CalendarState get initialState => _state.value;
  Stream<CalendarState> get state => _state.stream.distinct();

  final _state = BehaviorSubject<CalendarState>.seeded(
    CalendarState(
      selectedDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    ),
  );

  StreamSubscription<List<TodoEntity>> _todosSubscription;

  CalendarBloc() {
    _actions.stream.listen((action) {
      switch (action.runtimeType) {
        case UpdateField:
          _onUpdateField(action);
          break;
        case PerformOnTodo:
          _onPerform(action);
          break;
        case ToggleArchive:
          _onToggle();
          break;
        case ClearDailyArchive:
          _onClearDailyArchive();
          break;
        default:
          assert(false);
      }
    });

    _todosSubscription = dependencies.todoInteractor.all.listen((data) {
      final todos = data.where((todo) => todo.dueDate != null);
      final active = todos.where((todo) => todo.status == TodoStatus.active);
      final archived = todos.where((todo) => todo.status == TodoStatus.finished);

      final activeEvents = groupBy(active, (TodoEntity todo) => todo.dueDate);
      final archivedEvents = groupBy(archived, (TodoEntity todo) => todo.dueDate);

      _state.add(_state.value.rebuild(
        (b) => b
          ..activeEvents = MapBuilder(activeEvents)
          ..archivedEvents = MapBuilder(archivedEvents),
      ));
    });

    state.listen((data) {
      _state.add(_state.value.rebuild(
        (b) => b
          ..activeTodos = ListBuilder(b.activeEvents[b.selectedDate] ?? [])
          ..archivedTodos = ListBuilder(b.archivedEvents[b.selectedDate] ?? []),
      ));
    });
  }

  void dispose() {
    _actions.close();
    _state.close();
    _todosSubscription.cancel();
  }

  void _onUpdateField(UpdateField action) {
    final state = _state.value.toBuilder();

    switch (action.field) {
      case Field.selectedDate:
        state.selectedDate = action.value;
        break;
      case Field.calendarFormat:
        state.calendarFormat = action.value;
        break;
      case Field.calendarVisible:
        state.calendarVisible = action.value;
        break;
      default:
        assert(false);
    }

    _state.add(state.build());
  }

  void _onPerform(PerformOnTodo action) {
    switch (action.operation) {
      case Operation.add:
        _onAdd(action.todo);
        break;
      case Operation.favorite:
        _onFavorite(action.todo);
        break;
      case Operation.archive:
        _onArchive(action.todo);
        break;
      default:
        assert(false);
    }
  }

  void _onAdd(TodoEntity todo) {
    _state.add(_state.value.rebuild(
      (b) => b..todoNameHasError = isBlank(todo.name),
    ));

    if (_state.value.todoNameHasError) {
      return;
    }

    dependencies.todoInteractor.add(todo);
  }

  void _onFavorite(TodoEntity todo) {
    dependencies.todoInteractor.update(
      todo.rebuild((b) => b..isFavorite = !b.isFavorite),
    );
  }

  void _onArchive(TodoEntity todo) {
    dependencies.todoInteractor.archiveTodo(
      todo.rebuild(
        (b) => b
          ..status = TodoStatus.finished
          ..finishedDate = DateTime.now(),
      ),
    );
  }

  void _onToggle() {
    _state.add(_state.value.rebuild((b) => b..archiveVisible = !b.archiveVisible));
  }

  void _onClearDailyArchive() {
    dependencies.todoInteractor.clearDailyArchive(_state.value.selectedDate);
  }
}
