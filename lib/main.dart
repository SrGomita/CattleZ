import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Importación de AppLocalizations



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString('languageCode') ?? 'en';
  runApp(MyApp(languageCode: languageCode));
}

class MyApp extends StatefulWidget {
  final String languageCode;
  

  const MyApp({super.key, required this.languageCode});

  @override
  MyAppState createState() => MyAppState();

  static MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>();
}

class MyAppState extends State<MyApp> {
  late Locale _locale;
  ThemeData? _themeData;
  

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.languageCode);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    setState(() {
      _themeData = isDarkTheme ? ThemeData.dark() : ThemeData.light();
    });
  }

  void _changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  void changeTheme(bool isDarkTheme) {
    setState(() {
      _themeData = isDarkTheme ? ThemeData.dark() : ThemeData.light();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cow Tracker',
      theme: _themeData,
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate, // Delegado para traducciones
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español
      ],
      home: MainNavigation(
        onLanguageChange: _changeLanguage,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final Function(String) onLanguageChange;

  const MainNavigation({super.key, required this.onLanguageChange});

  @override
  MainNavigationState createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    CowListPage(),
    CalendarPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.cowTracker), // Traducción dinámica
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsPage(
                  onLanguageChange: widget.onLanguageChange,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.jumpToPage(index); // Sincronizar con PageView
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: localizations.cows, // Traducción dinámica
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: localizations.calendar, // Traducción dinámica
          ),
        ],
      ),
    );
  }
}

class Cow {
  final String name;
  bool isPregnant;  // Cambiado a 'bool' para permitir cambios en el estado
  DateTime? pregnancyDate;
  final String id;
  bool hasCalved; 

  Cow({
    required this.id,
    required this.name,
    required this.isPregnant,
    this.pregnancyDate,
    this.hasCalved = false,
  });

  void checkAndChangeStatus() {
    if (isPregnant && dueDate != null && DateTime.now().isAfter(dueDate!)) {
      isPregnant = true; // La vaca sigue embarazada
      hasCalved = true; // La vaca ha parido
    }
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();  // Genera un id único basado en el tiempo
  }

  DateTime? get dueDate =>
      pregnancyDate?.add(Duration(days: 283)); // Calcula la fecha estimada de parto

  // Método para alternar el estado de embarazo de la vaca
  void togglePregnancyStatus() {
    isPregnant = !isPregnant;
    if (!isPregnant) {
      pregnancyDate = null; // Limpiar la fecha de embarazo si no está preñada
    }
  }

  factory Cow.fromMap(Map<String, dynamic> map) {
    return Cow(
      id: map['id'] as String,  // Asegúrate de incluir el id
      name: map['name'] as String,
      isPregnant: map['isPregnant'] as bool,
      pregnancyDate: map['pregnancyDate'] != null
          ? DateTime.parse(map['pregnancyDate'] as String)
          : null,
      hasCalved: map['hasCalved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isPregnant': isPregnant,
      'pregnancyDate': pregnancyDate?.toIso8601String(),
      'hasCalved': hasCalved,
    };
  }
}

class CowListPage extends StatefulWidget {
  const CowListPage({super.key});

  @override
  CowListPageState createState() => CowListPageState();
}

class CowListPageState extends State<CowListPage> {
  List<Cow> cows = [];
  String filter = "all";
  String sortBy = "name";
  bool ascending = true;

  @override
  void initState() {
    super.initState();
    _loadCows();
  }

Future<void> _loadCows() async {
  final prefs = await SharedPreferences.getInstance();
  final cowData = prefs.getStringList('cows') ?? [];
  setState(() {
    cows = cowData.map((e) => Cow.fromMap(jsonDecode(e))).toList();
  });

  // Verificar y actualizar el estado de las vacas
  for (var cow in cows) {
    cow.checkAndChangeStatus();  // Cambia el estado de embarazada a parida si corresponde
  }

  // Guardar las vacas con los estados actualizados
  _saveCows();
}


  Future<void> _saveCows() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cows', cows.map((cow) => jsonEncode(cow.toMap())).toList());
  }

List<Cow> _getFilteredAndSortedCows() {
  List<Cow> filteredCows = [];

  switch (filter) {
    case "pregnant":
      // Filtrar vacas que están embarazadas y no han parido
      filteredCows = cows.where((cow) => cow.isPregnant && !cow.hasCalved).toList();
      break;
    case "not_pregnant":
      // Filtrar vacas que no están embarazadas
      filteredCows = cows.where((cow) => !cow.isPregnant).toList();
      break;
    case "has_calved":
      // Filtrar vacas que están embarazadas y que también han parido
      filteredCows = cows.where((cow) => cow.isPregnant && cow.hasCalved).toList();
      break;
    default:
      // Mostrar todas las vacas
      filteredCows = List.from(cows);
  }

  // Ordenar las vacas
  filteredCows.sort((a, b) {
    int result;
    if (sortBy == "name") {
      result = a.name.compareTo(b.name);
    } else {
      result = a.dueDate?.compareTo(b.dueDate ?? DateTime(0)) ?? 0;
    }
    return ascending ? result : -result;
  });

  return filteredCows;
}

void _addOrEditCow([String? id]) {
  final localizations = AppLocalizations.of(context)!;
  final nameController = TextEditingController(
      text: id != null ? cows.firstWhere((cow) => cow.id == id).name : '');
  final pregnancyController = TextEditingController(
      text: id != null && cows.firstWhere((cow) => cow.id == id).pregnancyDate != null
          ? DateFormat('yyyy-MM-dd').format(cows.firstWhere((cow) => cow.id == id).pregnancyDate!)
          : '');

  bool isPregnant = pregnancyController.text.isNotEmpty; // Usamos bool en lugar de bool?

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(id == null
          ? localizations.addCow // Texto dinámico
          : localizations.editCow),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: localizations.cowName),
          ),
          Row(
            children: [
              PregnancyCheckbox(
                initialValue: isPregnant,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      // Si se marca el checkbox, aseguramos que la fecha sea asignada si está vacía
                      if (pregnancyController.text.isEmpty) {
                        pregnancyController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      }
                    } else {
                      pregnancyController.text = ''; // Limpiar fecha si se desmarca el checkbox
                    }
                    isPregnant = value!; // Actualizar el valor de isPregnant
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: pregnancyController.text.isNotEmpty
                          ? DateFormat('yyyy-MM-dd').parse(pregnancyController.text)
                          : DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        pregnancyController.text = DateFormat('yyyy-MM-dd').format(date);
                        isPregnant = true; // Asegurarse de que el checkbox esté marcado
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: pregnancyController,
                      decoration:
                          InputDecoration(labelText: localizations.pregnancyDate),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;

            final pregnancyDate = isPregnant
                ? DateFormat('yyyy-MM-dd').parse(pregnancyController.text)
                : null;

            setState(() {
              if (id == null) {
                cows.add(Cow(
                  id: Cow.generateId(),
                  name: name,
                  isPregnant: isPregnant,
                  pregnancyDate: pregnancyDate,
                ));
              } else {
                final cowIndex = cows.indexWhere((cow) => cow.id == id);
                if (cowIndex != -1) {
                  cows[cowIndex] = Cow(
                    id: id,
                    name: name,
                    isPregnant: isPregnant,
                    pregnancyDate: pregnancyDate,
                  );
                }
              }
            });

            _saveCows();
            Navigator.pop(context);
          },
          child: Text(id == null ? localizations.add : localizations.save),
        ),
      ],
    ),
  );
}



void _deleteCow(String cowId) {
  final localizations = AppLocalizations.of(context)!;
  final cow = cows.firstWhere((cow) => cow.id == cowId);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.confirmDeletion),
      content: Text(
          localizations.deleteCowConfirmation(cow.name)), // Texto dinámico con parámetro
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              cows.removeWhere((cow) => cow.id == cowId);
            });
            _saveCows();
            Navigator.pop(context);
          },
          child: Text(localizations.delete),
        ),
      ],
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    final filteredAndSortedCows = _getFilteredAndSortedCows();

    return Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              DropdownButton<String>(
                value: filter,
                items: [
                  DropdownMenuItem(value: "all", child: Text("All")),
                  DropdownMenuItem(value: "pregnant", child: Text("Pregnant")),
                  DropdownMenuItem(value: "not_pregnant", child: Text("Not Pregnant")),
                  DropdownMenuItem(value: "has_calved", child: Text("Has Calved")),
                ],
                onChanged: (value) {
                  setState(() {
                    filter = value!;
                  });
                },
              ),
              DropdownButton<String>(
                value: sortBy,
                items: [
                  DropdownMenuItem(value: "name", child: Text("Name")),
                  DropdownMenuItem(value: "due_date", child: Text("Due Date")),
                ],
                onChanged: (value) {
                  setState(() {
                    sortBy = value!;
                  });
                },
              ),
              IconButton(
                icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () {
                  setState(() {
                    ascending = !ascending;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredAndSortedCows.length,
              itemBuilder: (context, index) {
                final cow = filteredAndSortedCows[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'), // Mostrar el número de la vaca
                  ),
                  title: Text(cow.name),
                  subtitle: Text(cow.isPregnant && cow.dueDate != null
                      ? '${AppLocalizations.of(context)!.dueDateLabel}: ${DateFormat('yyyy-MM-dd').format(cow.dueDate!)}'
                      : AppLocalizations.of(context)!.notPregnantLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _addOrEditCow(cow.id), // Cambiado a pasar el 'id' de la vaca
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteCow(cow.id), // Cambiado a pasar el 'id' de la vaca
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCow(),
        child: Icon(Icons.add),
      ),
    );
  }
}

class PregnancyCheckbox extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool?> onChanged;

  const PregnancyCheckbox({super.key, required this.initialValue, required this.onChanged});

  @override
  PregnancyCheckboxState createState() => PregnancyCheckboxState();
}

class PregnancyCheckboxState extends State<PregnancyCheckbox> {
  late bool isPregnant;

  @override
  void initState() {
    super.initState();
    isPregnant = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isPregnant,
          onChanged: (bool? value) {
            setState(() {
              isPregnant = value ?? false;
            });
            widget.onChanged(isPregnant);
          },
        ),
      ],
    );
  }
}


class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  DateTime selectedDate = DateTime.now();
  List<Cow> cows = [];
  Map<DateTime, List<Cow>> _partoDates = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadCows();
  }

  Future<void> _loadCows() async {
    final prefs = await SharedPreferences.getInstance();
    final cowData = prefs.getStringList('cows') ?? [];
    setState(() {
      cows = cowData.map((e) => Cow.fromMap(jsonDecode(e))).toList();
      _partoDates = _getPartoDates();
    });
    print('Cows loaded: ${cows.length}');
  }

  Map<DateTime, List<Cow>> _getPartoDates() {
    Map<DateTime, List<Cow>> partoDates = {};
    for (var cow in cows) {
      if (cow.dueDate != null) {
        DateTime partoDate = DateTime.utc(cow.dueDate!.year, cow.dueDate!.month, cow.dueDate!.day);
        if (!partoDates.containsKey(partoDate)) {
          partoDates[partoDate] = [];
        }
        partoDates[partoDate]?.add(cow);
      }
    }
    print('Parto Dates: $partoDates');
    return partoDates;
  }

  List<Cow> _getCowsForSelectedDate() {
    print('Selected Date: $selectedDate');
    final filteredCows = cows.where((cow) {
      if (cow.dueDate == null) return false;
      return cow.dueDate!.year == selectedDate.year &&
             cow.dueDate!.month == selectedDate.month &&
             cow.dueDate!.day == selectedDate.day;
    }).toList();
    print('Cows for selected date: ${filteredCows.length}');
    return filteredCows;
  }

  @override
  Widget build(BuildContext context) {
    final cowsForSelectedDate = _getCowsForSelectedDate();
    
    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              });
            },
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) {
              final dateKey = DateTime.utc(day.year, day.month, day.day);
              return _partoDates[dateKey] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cowsForSelectedDate.length,
              itemBuilder: (context, index) {
                final cow = cowsForSelectedDate[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(cow.name),
                  subtitle: Text('${AppLocalizations.of(context)!.dueDateLabel}: ${DateFormat('yyyy-MM-dd').format(cow.dueDate!)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class SettingsPage extends StatefulWidget {
  final Function(String) onLanguageChange;

  const SettingsPage({super.key, required this.onLanguageChange});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late bool isDarkTheme;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
  }

Future<void> _toggleTheme(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDarkTheme', value);

  // Realiza el setState primero para actualizar la UI
  setState(() {
    isDarkTheme = value;
  });

  // Asegúrate de que el contexto esté disponible para cambiar el tema
  // Usamos un `WidgetsBinding.addPostFrameCallback` para hacerlo en el momento adecuado
  WidgetsBinding.instance.addPostFrameCallback((_) {
    MyApp.of(context)?.changeTheme(value);
  });
}

  @override
Widget build(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;

  return Scaffold(
    appBar: AppBar(
      title: Text(localizations.settings), // Usando la traducción
    ),
    body: Column(
      children: [
        ListTile(
          title: Text(localizations.darkTheme), // Traducción para 'Dark Theme'
          trailing: Switch(
            value: isDarkTheme,
            onChanged: _toggleTheme,
          ),
        ),
        ListTile(
          title: Text(localizations.language), // Traducción para 'Language'
          subtitle: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? localizations.english
                : localizations.spanish,
          ),
          onTap: () {
            final newLanguage = Localizations.localeOf(context).languageCode == 'en' ? 'es' : 'en';
            widget.onLanguageChange(newLanguage);
          },
        ),
      ],
    ),
  );
}
}