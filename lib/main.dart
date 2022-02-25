import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:simpleplanner/appdata_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


// Global schedule data
List<String> dirtySchedules = [];
Map<String, List<List>> scheduleContents = {};

// Global task data
bool isTaskDirty = false;
List<List> taskContents = [];

// Global monthly routine data
List<List> monthlyRoutineContents = [];
List<List> weeklyRoutineContents = [];
List<List> notificationContents = [];

// Other global variables
DateTime addScheduleInitialDate = DateTime.now();

// Constants
List<String> weekdays = weekdayNames[applicationSettings['generalLocale']]!;
List<String> monthdays = [for (int i = 1; i < 32; i++) i.toString()];
List<String> months = [for (int i = 1; i < 13; i++) i.toString()];
Map languagePack = {};

// Functions that saves all files
void saveAllFiles() {
  for (String targetDate in dirtySchedules) {
    saveScheduleFile(targetDate, scheduleContents[targetDate]);
  }

  saveTaskFile(taskContents);
  saveMonthlyRoutineFile(monthlyRoutineContents);
  saveWeeklyRoutineFile(weeklyRoutineContents);
  saveNotificationFile(notificationContents);
  saveSettingFile(applicationSettings);
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  applicationSettings = await readSettingFile();
  scheduleContents = await readAllScheduleFiles();
  taskContents = await readTaskFile();
  notificationContents = await readNotificationFile();
  monthlyRoutineContents = await readMonthlyRoutineFile();
  weeklyRoutineContents = await readWeeklyRoutineFile();
  languagePack = await readLanguagePackFile(applicationSettings['generalLocale'] ?? defaultApplicationSettings['generalLocale']!);

  print('===== $weeklyRoutineContents');

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ko', 'KR'),
      ],
      home: DailyScheduleMode(),
    );
  }
}

/*
 * AddScheduleMode (ScheduleManager)
 *   Form to add new schedule
 */
class AddScheduleMode extends StatefulWidget {
  const AddScheduleMode({Key? key}) : super(key: key);

  @override
  _AddScheduleModeState createState() => _AddScheduleModeState();
}

class _AddScheduleModeState extends State<AddScheduleMode> {
  DateTime targetDate = DateTime.now();
  String newdate = dateTime2String(DateTime.now());
  final _formKey = GlobalKey<FormState>();
  List<TextEditingController> scheduleTextController = [];
  List<Widget> scheduleFields = [];
  List<Widget> scheduleCheckbox = [];
  List<String> scheduleCheckboxValues = [];
  TextEditingController dateTextController = TextEditingController();
  bool isInitialized = false;
  bool isBackKeyActivated = true;
  bool dragTriggered = false;

  void reconfigureFields() {
    List dirtyScheduleTexts = [];
    List dirtyScheuleCheckboxValues = [];
    for (int index = 0; index < scheduleTextController.length; index++) {
      if (scheduleTextController[index].text.isNotEmpty) {
        dirtyScheduleTexts.add(scheduleTextController[index].text);
        dirtyScheuleCheckboxValues.add(scheduleCheckboxValues[index]);
      }
    }

    scheduleFields = [];
    scheduleTextController = [];
    scheduleCheckbox = [];
    scheduleCheckboxValues = [];

    // Initialize text fields
    for (int index = 0; index < dirtyScheduleTexts.length; index++) {
      addScheduleTextField(index, isChecked: dirtyScheuleCheckboxValues[index]);
      scheduleTextController[index].text = dirtyScheduleTexts[index];
    }

    // Append new empty text field
    if (scheduleFields.isEmpty) { addScheduleTextField(0); }
    if (scheduleTextController[scheduleTextController.length-1].text.isNotEmpty) { addScheduleTextField(scheduleFields.length); }
  }

  void removeUnnessesaryFields() {
    setState(() {
      int targetIndex = scheduleTextController.length-1;
      while (targetIndex > 0 &&
          scheduleTextController[targetIndex].text.isEmpty &&
          scheduleTextController[targetIndex-1].text.isEmpty) {
        deleteScheduleTextField(targetIndex);
        targetIndex -= 1;
      }
    });
  }

  void refreshCheckboxes() {
    setState(() {
      List dirtyScheuleCheckboxValues = [];
      for (int index = 0; index < scheduleCheckboxValues.length; index++) {
        dirtyScheuleCheckboxValues.add(scheduleCheckboxValues[index]);
      }

      scheduleCheckbox = [];
      scheduleCheckboxValues = [];

      // Initialize text fields
      for (int index = 0; index < dirtyScheuleCheckboxValues.length; index++) {
        scheduleCheckboxValues.add(dirtyScheuleCheckboxValues[index]);
        scheduleCheckbox.add(Checkbox(
          value: string2Bool(scheduleCheckboxValues[index]),
          activeColor: Colors.amber[800],
          onChanged: (bool? value) {
            scheduleCheckboxValues[index] = bool2String(value!);
            refreshCheckboxes();
          },
        ));
      }

    });
  }

  void addScheduleTextField(int index, {String isChecked = '0'}) {
    scheduleCheckboxValues.add(isChecked);
    scheduleCheckbox.add(Checkbox(
      value: string2Bool(scheduleCheckboxValues[index]),
      activeColor: Colors.amber[800],
      onChanged: (bool? value) {
        scheduleCheckboxValues[index] = bool2String(value!);
        refreshCheckboxes();
      },
    ));
    scheduleTextController.add(TextEditingController());
    scheduleFields.add(TextFormField(
      validator: (text) {
        if (text != null) {
          if (text.contains(',')) { return languagePack['schedule_manager_name_validation_comma']; }
        }
        return null;
      },
      controller: scheduleTextController[index],
      decoration: InputDecoration(
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
        labelText: "${languagePack['schedule_manager_index_prefix']!} ${index+1}", fillColor: Colors.black, floatingLabelStyle: TextStyle(color: Colors.black,),
      ),
      onChanged: (text) {
        int targetIndex = scheduleFields.indexOf(scheduleFields[index]);
        if (text.contains(',')) {
          scheduleTextController[targetIndex].text = scheduleTextController[targetIndex].text.replaceAll(',', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(languagePack['schedule_manager_name_validation_comma']), duration: Duration(seconds: 1),),
          );
        } else {
          if (text.isNotEmpty && targetIndex == scheduleFields.length-1) {
            setState(() {
              addScheduleTextField(scheduleFields.length);
            });
          } else if (text.isEmpty && targetIndex == scheduleFields.length-2) {
            removeUnnessesaryFields();
          }
        }},
    ));
  }

  void deleteScheduleTextField(int index) {
    setState(() {
      scheduleCheckbox.removeAt(index);
      scheduleCheckboxValues.removeAt(index);
      scheduleTextController.removeAt(index);
      scheduleFields.removeAt(index);
    });
  }

  void initializeFieldController() {
    if (!isInitialized) {
      scheduleCheckbox = [];
      scheduleCheckboxValues = [];
      scheduleFields = [];
      scheduleTextController = [];

      String convertedTargetDate = dateTime2StringWithoutWeekday(targetDate);

      // Initialize text fields
      if (scheduleContents[convertedTargetDate] != null) {
        for (int index = 0; index < scheduleContents[convertedTargetDate]!.length; index++) {
          if (index >= scheduleFields.length) {
            addScheduleTextField(index, isChecked: scheduleContents[convertedTargetDate]![index][1]);
          }
          if (!isInitialized) {
            scheduleTextController[index].text = scheduleContents[convertedTargetDate]![index][0];
          }
        }
      }
    }

    // Append new empty text field
    if (scheduleFields.isEmpty) { addScheduleTextField(0); }
    if (scheduleTextController[scheduleTextController.length-1].text.isNotEmpty) { addScheduleTextField(scheduleFields.length); }

    isInitialized = true;
  }

  Widget generateScheduleListView() {
    initializeFieldController();

    return ListView.builder(
      physics: BouncingScrollPhysics(),
      itemCount: scheduleFields.length,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, i) => Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(margin: EdgeInsets.only(top: 5),child: scheduleFields[i]),
            ),
            scheduleCheckbox[i],
          ],
        ),
      ),
    );
  }

  void saveNewSchedules() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      String convertedTargetDate = dateTime2StringWithoutWeekday(targetDate);

      scheduleContents[convertedTargetDate] = [];
      List<String>.generate(scheduleTextController.length, (int i) => scheduleTextController[i].text);
      for (int index = 0; index < scheduleTextController.length; index++) {
        if (scheduleTextController[index].text.isNotEmpty) {
          scheduleContents[convertedTargetDate]!.add([scheduleTextController[index].text, scheduleCheckboxValues[index]]);
        }
      }

      scheduleContents[convertedTargetDate]!.sort((a, b) => a[1].compareTo(b[1]));

      if (scheduleContents[convertedTargetDate]!.isEmpty) {
        scheduleContents.remove(convertedTargetDate);
      }

      dirtySchedules.add(convertedTargetDate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languagePack['schedule_manager_updated_msg']), duration: Duration(seconds: 1),),
      );

      saveAllFiles();
    }
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();

      // Checks if the current content is dirty
      bool isDirty = false;
      String convertedTargetDate = dateTime2StringWithoutWeekday(targetDate);
      List? savedSchedules = scheduleContents[convertedTargetDate];

      if (savedSchedules == null) {
        if (scheduleTextController.length > 1) {isDirty = true;}
      } else if (savedSchedules.length != scheduleTextController.length-1) {isDirty = true;}
      else {
        for (int index = 0; index < scheduleTextController.length-1; index++) {
          if (savedSchedules[index][0] != scheduleTextController[index].text) {isDirty = true;}
          if (savedSchedules[index][1] != scheduleCheckboxValues[index]) {isDirty = true;}
        }
      }

      // Dialog to check whehter to save the dirty contents
      if (isDirty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(languagePack['savecheck_title']),
              content: Text(languagePack['savecheck_msg']),
              actions: [
                TextButton(
                  child: Text(languagePack['savecheck_yes'], style: TextStyle(color: Colors.amber[800]),), onPressed: () {
                    saveNewSchedules();
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text(languagePack['savecheck_no'], style: TextStyle(color: Colors.black),), onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    targetDate = addScheduleInitialDate;
    newdate = dateTime2String(addScheduleInitialDate);
    dateTextController.text = newdate;
    initializeFieldController();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        onVerticalDragUpdate: (details) {},
        onHorizontalDragUpdate: (details) {
          if (dragTriggered) {
            if (details.delta.direction > 0) {
              setState(()  {
                isInitialized = false;
                targetDate = DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
                dateTextController.text = dateTime2String(targetDate);
                initializeFieldController();
              });
            } else {
              setState(() {
                isInitialized = false;
                targetDate = DateTime(targetDate.year, targetDate.month, targetDate.day - 1);
                dateTextController.text = dateTime2String(targetDate);
                initializeFieldController();
              });
            }

            dragTriggered = false;
          }
        },
        onHorizontalDragStart: (details) {
          dragTriggered = true;
        },
        child: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.save_rounded, color: Colors.black,),
                onPressed: () { saveNewSchedules(); },
                iconSize: 30,
              ),
            ],
            elevation: 0.0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
              onPressed: backKeyPressed,
              iconSize: 30,
            ),
            title: Text(languagePack['schedule_manager_title']),
            titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20,),
          ),

          body: Container(
            decoration: BoxDecoration(color: Colors.white,),
            child: Container(
              margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
              child: Form(
                key: _formKey,
                child: Column (
                  children: [
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                      child: TextFormField(
                        validator: (text) {
                          if (text != null) {
                            if (text.isEmpty) { return languagePack['schedule_manager_duedate_validation_empty']; }
                          }
                          return null;
                        },
                        controller: dateTextController,
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                          icon: Icon(Icons.calendar_today, color: Colors.black,),
                          labelText: languagePack["schedule_manager_duedate_label"],
                          fillColor: Colors.black,
                          floatingLabelStyle: TextStyle(color: Colors.black,),
                        ),
                        readOnly: true,
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            locale: Locale(applicationSettings['generalLocale']!.split('_')[0], applicationSettings['generalLocale']!.split('_')[1]),
                            context: context, initialDate: targetDate,
                            firstDate: DateTime(2000), lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black,),
                                  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(primary: Colors.black,),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if(pickedDate != null ){
                            String newdate = dateTime2String(pickedDate);
                            setState(() {
                              isInitialized = false;
                              targetDate = pickedDate;
                              dateTextController.text = newdate;
                            });
                          }
                        },
                        onChanged: (text) async {
                          if (text.isNotEmpty) {
                            setState(() {
                              initializeFieldController();
                            });
                          }
                        },
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 0, 5), alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text( languagePack['schedule_manager_subtitle'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,), ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.only(right: 15),
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      child: Text('<<  ${languagePack['schedule_manager_previous']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),),
                                      onPressed: () {
                                        setState(() {
                                          isInitialized = false;
                                          targetDate = DateTime(targetDate.year, targetDate.month, targetDate.day - 1);
                                          dateTextController.text = dateTime2String(targetDate);
                                          initializeFieldController();
                                        });
                                        },
                                    ),
                                  ),
                                ),

                                Container(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    child: Text('${languagePack['schedule_manager_next']}  >>', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),),
                                    onPressed: () {
                                      setState(() {
                                        isInitialized = false;
                                        targetDate = DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
                                        dateTextController.text = dateTime2String(targetDate);
                                        initializeFieldController();
                                      });
                                      },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Container(
                        width: double.infinity, height: double.infinity, margin: EdgeInsets.all(5),
                        child: generateScheduleListView(),
                      )
                    ),
                  ],
                )
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/*
 * AddTaskMode(TaskManager)
 *   Form to add new schedule
 */
class AddTaskMode extends StatefulWidget {
  final int initialTaskIndex;

  const AddTaskMode({Key? key, this.initialTaskIndex = -1}) : super(key: key);

  @override
  _AddTaskModeState createState() => _AddTaskModeState();
}

class _AddTaskModeState extends State<AddTaskMode> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController tasknameController = TextEditingController();
  TextEditingController startdateController = TextEditingController();
  TextEditingController duedateController = TextEditingController();
  List<List> dirtyTaskContents = List.from(taskContents);
  bool isChecked = false;
  bool isInitialized = false;
  bool isAddNewTaskMode = true;
  bool isBackKeyActivated = true;
  bool isDirty = false;
  int selectedIndex = -1;

  void initializeTasks() {
    if (!isInitialized) {
      dirtyTaskContents = List.from(taskContents);
      dirtyTaskContents.sort((a, b) => b[2].compareTo(a[2]),);
      dirtyTaskContents.sort((a, b) => a[3].compareTo(b[3]),);
    }

    if (widget.initialTaskIndex == -1) {
      startdateController.text = dateTime2String(DateTime.now());
      duedateController.text = dateTime2String(DateTime.now());
    } else {
      selectedIndex = dirtyTaskContents.indexOf(taskContents[widget.initialTaskIndex]);
      isAddNewTaskMode = false;
      tasknameController.text = dirtyTaskContents[selectedIndex][0];
      startdateController.text = dirtyTaskContents[selectedIndex][1];
      duedateController.text = dirtyTaskContents[selectedIndex][2];
      isChecked = string2Bool(dirtyTaskContents[selectedIndex][3]);
    }

    isInitialized = true;
    isDirty = false;
  }

  void saveNewTasks() {
    FocusScope.of(context).unfocus();

    isBackKeyActivated = false;
    taskContents = List.from(dirtyTaskContents);
    isBackKeyActivated = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languagePack['task_manager_updated_msg']), duration: Duration(seconds: 1),),
    );

    isDirty = false;

    saveAllFiles();
  }

  void addNewTask() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyTaskContents.add([tasknameController.text, startdateController.text, duedateController.text, bool2String(isChecked)]);
        dirtyTaskContents.sort((a, b) => b[2].compareTo(a[2]),);
        dirtyTaskContents.sort((a, b) => a[3].compareTo(b[3]),);
        tasknameController.text = '';
        startdateController.text = dateTime2String(DateTime.now());
        duedateController.text = dateTime2String(DateTime.now());
        isChecked = false;
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void refreshSelectedTask() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyTaskContents[selectedIndex] = [tasknameController.text, startdateController.text, duedateController.text, bool2String(isChecked)];
        dirtyTaskContents.sort((a, b) => b[2].compareTo(a[2]),);
        dirtyTaskContents.sort((a, b) => a[3].compareTo(b[3]),);
        isAddNewTaskMode = true;
        tasknameController.text = '';
        startdateController.text = dateTime2String(DateTime.now());
        duedateController.text = dateTime2String(DateTime.now());
        isChecked = false;
        selectedIndex = -1;
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void deleteSelectedTask() {
    setState(() {
      if (!isAddNewTaskMode) {
        dirtyTaskContents.removeAt(selectedIndex);
        selectedIndex = -1;
        isAddNewTaskMode = true;
        tasknameController.text = '';
        startdateController.text = dateTime2String(DateTime.now());
        duedateController.text = dateTime2String(DateTime.now());
        isChecked = false;
        isDirty = true;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();

      // Dialog to check whehter to save the dirty contents
      if (isDirty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(languagePack['savecheck_title']),
              content: Text(languagePack['savecheck_msg']),
              actions: [
                TextButton(
                  child: Text(languagePack['savecheck_yes'], style: TextStyle(color: Colors.amber[800]),), onPressed: () {
                  saveNewTasks();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
                TextButton(
                  child: Text(languagePack['savecheck_no'], style: TextStyle(color: Colors.black),), onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initializeTasks();
    selectedIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save_rounded, color: Colors.black,),
              onPressed: () { saveNewTasks(); },
              iconSize: 30,
            ),
          ],
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['task_manager_title']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          decoration: BoxDecoration(color: Colors.white,),
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: TextFormField(
                          controller: tasknameController,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                            icon: Icon(Icons.list_alt_outlined, color: Colors.black,),
                            labelText: languagePack['task_manager_name_label'], fillColor: Colors.black, floatingLabelStyle: TextStyle(color: Colors.black,),
                          ),
                          validator: (text) {
                            if (text != null) {
                              if (text.isEmpty) { return languagePack['task_manager_name_validation_empty']; }
                              if (text.contains(',')) { return languagePack['task_manager_name_validation_comma']; }
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: TextFormField(
                                      validator: (text) {
                                        if (text != null) {
                                          if (text.isEmpty) { return languagePack['task_manager_startdate_validation_empty']; }
                                          if (string2DateTime(text).isAfter(string2DateTime(duedateController.text))) {
                                            return languagePack['task_manager_startdate_validation_after'];
                                          }
                                        }
                                        return null;
                                      },
                                      controller: startdateController,
                                      decoration: InputDecoration(
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                                        icon: Icon(Icons.calendar_today, color: Colors.black,),
                                        labelText: languagePack['task_manager_startdate_label'],
                                        fillColor: Colors.black,
                                        floatingLabelStyle: TextStyle(color: Colors.black,),
                                      ),
                                      readOnly: true,
                                      onTap: () async {
                                        DateTime? pickedDate = await showDatePicker(
                                          context: context, initialDate: DateTime.now(),
                                          firstDate: DateTime(2000), lastDate: DateTime(2101),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: ColorScheme.light(primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black,),
                                                textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(primary: Colors.black,),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );

                                        if(pickedDate != null ){
                                          setState(() {
                                            startdateController.text = dateTime2String(pickedDate);
                                          });
                                        }
                                      },
                                    ),
                                  ),

                                  TextFormField(
                                    validator: (text) {
                                      if (text != null) {
                                        if (text.isEmpty) { return languagePack['task_manager_duedate_validation_empty']; }
                                        if (string2DateTime(text).isBefore(string2DateTime(startdateController.text))) {
                                          return languagePack['task_manager_duedate_validation_after'];
                                        }
                                      }
                                      return null;
                                    },
                                    controller: duedateController,
                                    decoration: InputDecoration(
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                                      icon: Icon(Icons.calendar_today, color: Colors.black,),
                                      labelText: languagePack['task_manager_duedate_label'],
                                      fillColor: Colors.black,
                                      floatingLabelStyle: TextStyle(color: Colors.black,),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      DateTime? pickedDate = await showDatePicker(
                                        context: context, initialDate: DateTime.now(),
                                        firstDate: DateTime(2000), lastDate: DateTime(2101),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: ColorScheme.light(primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black,),
                                              textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(primary: Colors.black,),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );

                                      if(pickedDate != null ){
                                        setState(() {
                                          duedateController.text = dateTime2String(pickedDate);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: isChecked,
                              activeColor: Colors.amber[800],
                              onChanged: (value) {
                                setState(() { isChecked = value!; });
                              },
                            )
                          ],
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                            child: Text(languagePack['task_manager_subtitle'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
                          ),

                          Expanded(
                            child: Container(
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                              alignment: Alignment.centerRight,
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: (isAddNewTaskMode ? Colors.black : Colors.grey),),
                                    onPressed: addNewTask, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_rounded, color: (!isAddNewTaskMode ? Colors.black : Colors.grey),),
                                    onPressed: deleteSelectedTask, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.refresh_rounded, color: (!isAddNewTaskMode ? Colors.black : Colors.grey),),
                                    onPressed: refreshSelectedTask, iconSize: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: dirtyTaskContents.isEmpty ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: Text(languagePack['task_manager_empty_msg'], style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
                    ),),
                  ) : ListView.builder(
                    physics: BouncingScrollPhysics(),
                    itemCount: dirtyTaskContents.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: ((context, index) => GestureDetector(
                      onTap: () { setState(() {
                        if (isAddNewTaskMode) {
                          selectedIndex = index;
                          isAddNewTaskMode = false;
                          tasknameController.text = dirtyTaskContents[index][0];
                          startdateController.text = dirtyTaskContents[index][1];
                          duedateController.text = dirtyTaskContents[index][2];
                          isChecked = string2Bool(dirtyTaskContents[index][3]);
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewTaskMode && selectedIndex == index) {
                          selectedIndex = -1;
                          isAddNewTaskMode = true;
                          tasknameController.text = '';
                          startdateController.text = dateTime2String(DateTime.now());
                          duedateController.text = dateTime2String(DateTime.now());
                          isChecked = false;
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewTaskMode && selectedIndex != index) {
                          selectedIndex = index;
                          tasknameController.text = dirtyTaskContents[index][0];
                          startdateController.text = dirtyTaskContents[index][1];
                          duedateController.text = dirtyTaskContents[index][2];
                          isChecked = string2Bool(dirtyTaskContents[index][3]);
                          FocusScope.of(context).unfocus();
                        }
                      }); },
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: selectedIndex == index ? Color.fromRGBO(255, 222, 222, 1) : Colors.white,
                        ),
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                alignment: Alignment.centerLeft,
                                child: Text(dirtyTaskContents[index][0], style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500,
                                  decoration: dirtyTaskContents[index][3] == '1' ? TextDecoration.lineThrough : TextDecoration.none,
                                  color: dirtyTaskContents[index][2] == dateTime2String(DateTime.now()) ? Colors.red : (string2DateTime(dirtyTaskContents[index][2]).isBefore(DateTime.now()) ? Colors.grey : Colors.black),
                                ),),
                              ),
                            ),

                            Expanded(
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                child: Text('~${addWeekday2String(dirtyTaskContents[index][2])}', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey,
                                ),),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/*
 * Add Notification Mode Widget
 *   Form to add new notification
 */
class AddNotificationMode extends StatefulWidget {
  final List<List> saveRoute;
  const AddNotificationMode({Key? key, this.saveRoute = const []}) : super(key: key);

  @override
  _AddNotificationModeState createState() => _AddNotificationModeState();
}

class _AddNotificationModeState extends State<AddNotificationMode> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController notificationController = TextEditingController();
  String selectedDay = monthdays[0];
  String selectedMonth = months[0];
  String selectedNotificationDate = months[0] + '-' + monthdays[0];
  List<List> dirtyNotificationContents = List.from(taskContents);
  bool isInitialized = false;
  bool isAddNewNotificationMode = true;
  bool isBackKeyActivated = true;
  bool isDirty = false;
  int selectedIndex = -1;

  void initializeNotifications() {
    if (!isInitialized) {
      dirtyNotificationContents = List.from(notificationContents);
      dirtyNotificationContents.sort((a, b) {
        List aSplitted = a[1].split('-');
        List bSplitted = b[1].split('-');
        if (aSplitted[0] == bSplitted[0]) {
          return int.parse(aSplitted[1]).compareTo(int.parse(bSplitted[1]));
        }
        return int.parse(aSplitted[0]).compareTo(int.parse(bSplitted[0]));
      },);
    }
    isInitialized = true;
    isDirty = false;
  }

  void saveNewNotification() {
    FocusScope.of(context).unfocus();

    isBackKeyActivated = false;
    notificationContents = List.from(dirtyNotificationContents);
    isBackKeyActivated = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languagePack['notification_manager_updated_msg']), duration: Duration(seconds: 1),),
    );

    isDirty = false;

    saveAllFiles();
  }

  void addNewNotification() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyNotificationContents.add([notificationController.text, selectedNotificationDate]);
        dirtyNotificationContents.sort((a, b) {
          List aSplitted = a[1].split('-');
          List bSplitted = b[1].split('-');
          if (aSplitted[0] == bSplitted[0]) {
            return int.parse(aSplitted[1]).compareTo(int.parse(bSplitted[1]));
          }
          return int.parse(aSplitted[0]).compareTo(int.parse(bSplitted[0]));
        },);
        notificationController.text = '';
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void refreshSelectedNotification() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyNotificationContents[selectedIndex] = [notificationController.text, selectedNotificationDate];
        dirtyNotificationContents.sort((a, b) {
          List aSplitted = a[1].split('-');
          List bSplitted = b[1].split('-');
          if (aSplitted[0] == bSplitted[0]) {
            return int.parse(aSplitted[1]).compareTo(int.parse(bSplitted[1]));
          }
          return int.parse(aSplitted[0]).compareTo(int.parse(bSplitted[0]));
        },);
        isAddNewNotificationMode = true;
        notificationController.text = '';
        selectedIndex = -1;
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void deleteSelectedNotification() {
    setState(() {
      if (!isAddNewNotificationMode) {
        dirtyNotificationContents.removeAt(selectedIndex);
        selectedIndex = -1;
        isAddNewNotificationMode = true;
        notificationController.text = '';
        isDirty = true;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();

      // Dialog to check whehter to save the dirty contents
      if (isDirty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(languagePack['savecheck_title']),
              content: Text(languagePack['savecheck_msg']),
              actions: [
                TextButton(
                  child: Text(languagePack['savecheck_yes'], style: TextStyle(color: Colors.amber[800]),), onPressed: () {
                  saveNewNotification();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
                TextButton(
                  child: Text(languagePack['savecheck_no'], style: TextStyle(color: Colors.black),), onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initializeNotifications();
    selectedIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save_rounded, color: Colors.black,),
              onPressed: () { saveNewNotification(); },
              iconSize: 30,
            ),
          ],
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['notification_manager_title']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          decoration: BoxDecoration(color: Colors.white,),
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: TextFormField(
                          controller: notificationController,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                            icon: Icon(Icons.list_alt_outlined, color: Colors.black,),
                            labelText: languagePack['notification_manager_name_label'], fillColor: Colors.black, floatingLabelStyle: TextStyle(color: Colors.black,),
                          ),
                          validator: (text) {
                            if (text != null) {
                              if (text.isEmpty) { return languagePack['notification_manager_name_validation_empty']; }
                              if (text.contains(',')) { return languagePack['notification_manager_name_validation_comma']; }
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.only(right:10),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.only(left:0, right:20),
                                      child: Text(languagePack['notification_manager_months_title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
                                    ),
                                    Expanded(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color:Colors.white,
                                            border: Border.all(color: Colors.black, width:1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),

                                          child:Padding(
                                              padding: EdgeInsets.only(left:10, right:10),
                                              child:DropdownButton(
                                                value: selectedMonth,
                                                items: months.map(
                                                      (value) {
                                                    return DropdownMenuItem (
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  },
                                                ).toList(),
                                                onChanged: (value){ //get value when changed
                                                  setState(() {
                                                    selectedMonth = value.toString();
                                                    selectedNotificationDate = selectedMonth + '-' + selectedDay;
                                                  });
                                                },
                                                style: TextStyle( color: Colors.black, fontSize: 16, ),
                                                underline: Container(),
                                                isExpanded: true,
                                              )
                                          )
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Expanded(
                              child: Container(
                                padding: EdgeInsets.only(left:10, right:0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.only(left:0, right:20),
                                      child: Text(languagePack['notification_manager_days_title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
                                    ),
                                    Expanded(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color:Colors.white,
                                            border: Border.all(color: Colors.black, width:1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),

                                          child:Padding(
                                              padding: EdgeInsets.only(left:10, right:10),
                                              child:DropdownButton(
                                                value: selectedDay,
                                                items: monthdays.map(
                                                      (value) {
                                                    return DropdownMenuItem (
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  },
                                                ).toList(),
                                                onChanged: (value){ //get value when changed
                                                  setState(() {
                                                    selectedDay = value.toString();
                                                    selectedNotificationDate = selectedMonth + '-' + selectedDay;
                                                  });
                                                },
                                                style: TextStyle( color: Colors.black, fontSize: 16, ),
                                                underline: Container(),
                                                isExpanded: true,
                                              )
                                          )
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                            child: Text(languagePack['notification_manager_subtitle'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
                          ),

                          Expanded(
                            child: Container(
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                              alignment: Alignment.centerRight,
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: (isAddNewNotificationMode ? Colors.black : Colors.grey),),
                                    onPressed: addNewNotification, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_rounded, color: (!isAddNewNotificationMode ? Colors.black : Colors.grey),),
                                    onPressed: deleteSelectedNotification, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.refresh_rounded, color: (!isAddNewNotificationMode ? Colors.black : Colors.grey),),
                                    onPressed: refreshSelectedNotification, iconSize: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: dirtyNotificationContents.isEmpty ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: Text(languagePack['notification_manager_empty_msg'], style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
                    ),),
                  ) : ListView.builder(
                    physics: BouncingScrollPhysics(),
                    itemCount: dirtyNotificationContents.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: ((context, index) => GestureDetector(
                      onTap: () { setState(() {
                        if (isAddNewNotificationMode) {
                          selectedIndex = index;
                          isAddNewNotificationMode = false;
                          notificationController.text = dirtyNotificationContents[index][0];
                          selectedNotificationDate = dirtyNotificationContents[index][1];
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewNotificationMode && selectedIndex == index) {
                          selectedIndex = -1;
                          isAddNewNotificationMode = true;
                          notificationController.text = '';
                          selectedMonth = months[0];
                          selectedDay = monthdays[0];
                          selectedNotificationDate = selectedMonth + '-' + selectedDay;
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewNotificationMode && selectedIndex != index) {
                          selectedIndex = index;
                          notificationController.text = dirtyNotificationContents[index][0];
                          selectedNotificationDate = dirtyNotificationContents[index][1];
                          FocusScope.of(context).unfocus();
                        }
                      }); },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: selectedIndex == index ? Color.fromRGBO(255, 222, 222, 1) : Colors.white,
                        ),
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Row(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              child: Text(dirtyNotificationContents[index][0], style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),),
                            ),

                            Expanded(
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                child: Text('${dirtyNotificationContents[index][1]}', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey,
                                ),),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/*
 * Monthly Routine Widget
 *   Widget for monthly routines
 */
class AddMonthlyRoutineMode extends StatefulWidget {
  const AddMonthlyRoutineMode({Key? key}) : super(key: key);

  @override
  _AddMonthlyRoutineModeState createState() => _AddMonthlyRoutineModeState();
}

class _AddMonthlyRoutineModeState extends State<AddMonthlyRoutineMode> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController routineNameController = TextEditingController();
  String selectedMonthday = monthdays[0];
  List<List> dirtyRoutineContents = List.from(taskContents);
  bool isInitialized = false;
  bool isAddNewRoutineMode = true;
  bool isBackKeyActivated = true;
  bool isDirty = false;
  int selectedIndex = -1;

  void initializeRoutines() {
    if (!isInitialized) {
      dirtyRoutineContents = List.from(monthlyRoutineContents);
      dirtyRoutineContents.sort((a, b) => a[1].compareTo(b[1]),);
    }
    isInitialized = true;
    isDirty = false;
  }

  void saveNewRoutines() {
    FocusScope.of(context).unfocus();

    isBackKeyActivated = false;
    monthlyRoutineContents = List.from(dirtyRoutineContents);
    isBackKeyActivated = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languagePack['monthly_routine_manager_updated_msg']), duration: Duration(seconds: 1),),
    );

    isDirty = false;

    saveAllFiles();
  }

  void addNewRoutine() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyRoutineContents.add([routineNameController.text, selectedMonthday]);
        dirtyRoutineContents.sort((a, b) => int.parse(a[1]).compareTo(int.parse(b[1])),);
        routineNameController.text = '';
        selectedMonthday = monthdays[0];
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void refreshSelectedRoutine() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyRoutineContents[selectedIndex] = [routineNameController.text, selectedMonthday];
        dirtyRoutineContents.sort((a, b) => int.parse(a[1]).compareTo(int.parse(b[1])),);
        isAddNewRoutineMode = true;
        routineNameController.text = '';
        selectedMonthday = monthdays[0];
        selectedIndex = -1;
        isDirty = true;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void deleteSelectedRoutine() {
    setState(() {
      if (!isAddNewRoutineMode) {
        dirtyRoutineContents.removeAt(selectedIndex);
        selectedIndex = -1;
        isAddNewRoutineMode = true;
        routineNameController.text = '';
        selectedMonthday = monthdays[0];
        isDirty = true;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();

      // Dialog to check whehter to save the dirty contents
      if (isDirty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(languagePack['savecheck_title']),
              content: Text(languagePack['savecheck_msg']),
              actions: [
                TextButton(
                  child: Text(languagePack['savecheck_yes'], style: TextStyle(color: Colors.amber[800]),), onPressed: () {
                  saveNewRoutines();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
                TextButton(
                  child: Text(languagePack['savecheck_no'], style: TextStyle(color: Colors.black),), onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initializeRoutines();
    selectedIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save_rounded, color: Colors.black,),
              onPressed: () { saveNewRoutines(); },
              iconSize: 30,
            ),
          ],
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['monthly_routine_manager_title']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          decoration: BoxDecoration(color: Colors.white,),
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: TextFormField(
                          controller: routineNameController,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                            icon: Icon(Icons.list_alt_outlined, color: Colors.black,),
                            labelText: languagePack['monthly_routine_manager_name_label'], fillColor: Colors.black, floatingLabelStyle: TextStyle(color: Colors.black,),
                          ),
                          validator: (text) {
                            if (text != null) {
                              if (text.isEmpty) { return languagePack['monthly_routine_manager_name_validation_empty']; }
                              if (text.contains(',')) { return languagePack['monthly_routine_manager_name_validation_comma']; }
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:Colors.white,
                              border: Border.all(color: Colors.black, width:1),
                              borderRadius: BorderRadius.circular(10),
                            ),

                            child:Padding(
                                padding: EdgeInsets.only(left:20, right:20),
                                child:DropdownButton(
                                  value: selectedMonthday,
                                  items: monthdays.map(
                                        (value) {
                                      return DropdownMenuItem (
                                        value: value,
                                        child: Text(value),
                                      );
                                    },
                                  ).toList(),
                                  onChanged: (value){ //get value when changed
                                    setState(() {
                                      selectedMonthday = value.toString();
                                    });
                                  },
                                  style: TextStyle( color: Colors.black, fontSize: 16, ),
                                  underline: Container(),
                                  isExpanded: true,
                                )
                            )
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                            child: Text(languagePack['monthly_routine_manager_subtitle'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
                          ),

                          Expanded(
                            child: Container(
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                              alignment: Alignment.centerRight,
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: (isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: addNewRoutine, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_rounded, color: (!isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: deleteSelectedRoutine, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.refresh_rounded, color: (!isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: refreshSelectedRoutine, iconSize: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: dirtyRoutineContents.isEmpty ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: Text(languagePack['monthly_routine_manager_empty_msg'], style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
                    ),),
                  ) : ListView.builder(
                    physics: BouncingScrollPhysics(),
                    itemCount: dirtyRoutineContents.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: ((context, index) => GestureDetector(
                      onTap: () { setState(() {
                        if (isAddNewRoutineMode) {
                          selectedIndex = index;
                          isAddNewRoutineMode = false;
                          routineNameController.text = dirtyRoutineContents[index][0];
                          selectedMonthday = dirtyRoutineContents[index][1];
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewRoutineMode && selectedIndex == index) {
                          selectedIndex = -1;
                          isAddNewRoutineMode = true;
                          routineNameController.text = '';
                          selectedMonthday = monthdays[0];
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewRoutineMode && selectedIndex != index) {
                          selectedIndex = index;
                          routineNameController.text = dirtyRoutineContents[index][0];
                          selectedMonthday = dirtyRoutineContents[index][1];
                          FocusScope.of(context).unfocus();
                        }
                      }); },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: selectedIndex == index ? Color.fromRGBO(255, 222, 222, 1) : Colors.white,
                        ),
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Row(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              child: Text(dirtyRoutineContents[index][0], style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),),
                            ),

                            Expanded(
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                child: Text('${languagePack['every']} ${dirtyRoutineContents[index][1]}' + (
                                    dirtyRoutineContents[index][1][dirtyRoutineContents[index][1].length-1] == '1' ? languagePack['radix1'] :
                                    dirtyRoutineContents[index][1][dirtyRoutineContents[index][1].length-1] == '2' ? languagePack['radix2'] :
                                    dirtyRoutineContents[index][1][dirtyRoutineContents[index][1].length-1] == '3' ? languagePack['radix3'] :
                                    languagePack['radix4']), style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey,
                                ),),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



/*
 * Weekly Routine Widget
 *   Widget for weekly routines
 */
class AddWeeklyRoutineMode extends StatefulWidget {
  const AddWeeklyRoutineMode({Key? key}) : super(key: key);

  @override
  _AddWeeklyRoutineModeState createState() => _AddWeeklyRoutineModeState();
}

class _AddWeeklyRoutineModeState extends State<AddWeeklyRoutineMode> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController routineNameController = TextEditingController();
  String selectedWeekday = weekdays[0];
  List<List> dirtyRoutineContents = List.from(weeklyRoutineContents);
  bool isInitialized = false;
  bool isAddNewRoutineMode = true;
  bool isBackKeyActivated = true;
  bool isDirty = false;
  int selectedIndex = -1;

  void initializeRoutines() {
    if (!isInitialized) {
      dirtyRoutineContents = List.from(weeklyRoutineContents);
      dirtyRoutineContents.sort((a, b) => weekdays.indexOf(a[1]).compareTo(weekdays.indexOf(b[1])),);
    }
    isInitialized = true;
    isDirty = false;
  }

  void saveNewRoutines() {
    FocusScope.of(context).unfocus();

    isBackKeyActivated = false;
    weeklyRoutineContents = List.from(dirtyRoutineContents);
    isBackKeyActivated = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languagePack['weekly_routine_manager_updated_msg']), duration: Duration(seconds: 1),),
    );

    isDirty = false;

    saveAllFiles();
  }

  void addNewRoutine() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyRoutineContents.add([routineNameController.text, weekdays.indexOf(selectedWeekday).toString()]);
        dirtyRoutineContents.sort((a, b) => weekdays.indexOf(a[1]).compareTo(weekdays.indexOf(b[1])),);
        routineNameController.text = '';
        selectedWeekday = weekdays[0];
      });
      isDirty = true;
    }
    FocusScope.of(context).unfocus();
  }

  void refreshSelectedRoutine() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        dirtyRoutineContents[selectedIndex] = [routineNameController.text, weekdays.indexOf(selectedWeekday).toString()];
        dirtyRoutineContents.sort((a, b) => weekdays.indexOf(a[1]).compareTo(weekdays.indexOf(b[1])),);
        isAddNewRoutineMode = true;
        routineNameController.text = '';
        selectedWeekday = weekdays[0];
        isDirty = true;
        selectedIndex = -1;
      });
    }
    FocusScope.of(context).unfocus();
  }

  void deleteSelectedRoutine() {
    setState(() {
      if (!isAddNewRoutineMode) {
        dirtyRoutineContents.removeAt(selectedIndex);
        selectedIndex = -1;
        isAddNewRoutineMode = true;
        routineNameController.text = '';
        selectedWeekday = weekdays[0];
        isDirty = true;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();

      // Dialog to check whehter to save the dirty contents
      if (isDirty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(languagePack['savecheck_title']),
              content: Text(languagePack['savecheck_msg']),
              actions: [
                TextButton(
                  child: Text(languagePack['savecheck_yes'], style: TextStyle(color: Colors.amber[800]),), onPressed: () {
                    saveNewRoutines();
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text(languagePack['savecheck_no'], style: TextStyle(color: Colors.black),), onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initializeRoutines();
    selectedIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save_rounded, color: Colors.black,),
              onPressed: () { saveNewRoutines(); },
              iconSize: 30,
            ),
          ],
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['weekly_routine_manager_title']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          decoration: BoxDecoration(color: Colors.white,),
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: TextFormField(
                          controller: routineNameController,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(width: 1, color: Colors.black),),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)),),
                            icon: Icon(Icons.list_alt_outlined, color: Colors.black,),
                            labelText: languagePack['weekly_routine_manager_name_label'], fillColor: Colors.black, floatingLabelStyle: TextStyle(color: Colors.black,),
                          ),
                          validator: (text) {
                            if (text != null) {
                              if (text.isEmpty) { return languagePack['weekly_routine_manager_name_validation_empty']; }
                              if (text.contains(',')) { return languagePack['weekly_routine_manager_name_validation_comma']; }
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color:Colors.white,
                                border: Border.all(color: Colors.black, width:1),
                                borderRadius: BorderRadius.circular(10),
                            ),

                            child:Padding(
                                padding: EdgeInsets.only(left:20, right:20),
                                child:DropdownButton(
                                  value: selectedWeekday,
                                  items:weekdays.map((value) {
                                    return DropdownMenuItem (
                                      value: value,
                                      child: Text(value),
                                    );},
                                  ).toList(),
                                  onChanged: (value){ //get value when changed
                                    setState(() {
                                      selectedWeekday = value.toString();
                                    });
                                  },
                                  style: TextStyle( color: Colors.black, fontSize: 16, ),
                                  underline: Container(),
                                  isExpanded: true,
                                )
                            )
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                            child: Text(languagePack['weekly_routine_manager_subtitle'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
                          ),

                          Expanded(
                            child: Container(
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                              alignment: Alignment.centerRight,
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: (isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: addNewRoutine, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_rounded, color: (!isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: deleteSelectedRoutine, iconSize: 30,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.refresh_rounded, color: (!isAddNewRoutineMode ? Colors.black : Colors.grey),),
                                    onPressed: refreshSelectedRoutine, iconSize: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: dirtyRoutineContents.isEmpty ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: Text(languagePack['weekly_routine_manager_empty_msg'], style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
                    ),),
                  ) : ListView.builder(
                    physics: BouncingScrollPhysics(),
                    itemCount: dirtyRoutineContents.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: ((context, index) => GestureDetector(
                      onTap: () { setState(() {
                        if (isAddNewRoutineMode) {
                          selectedIndex = index;
                          isAddNewRoutineMode = false;
                          routineNameController.text = dirtyRoutineContents[index][0];
                          selectedWeekday = dirtyRoutineContents[index][1];
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewRoutineMode && selectedIndex == index) {
                          selectedIndex = -1;
                          isAddNewRoutineMode = true;
                          routineNameController.text = '';
                          selectedWeekday = weekdays[0];
                          FocusScope.of(context).unfocus();
                        } else if (!isAddNewRoutineMode && selectedIndex != index) {
                          selectedIndex = index;
                          routineNameController.text = dirtyRoutineContents[index][0];
                          selectedWeekday = dirtyRoutineContents[index][1];
                          FocusScope.of(context).unfocus();
                        }
                      }); },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: selectedIndex == index ? Color.fromRGBO(255, 222, 222, 1) : Colors.white,
                        ),
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Row(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              child: Text(dirtyRoutineContents[index][0], style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),),
                            ),

                            Expanded(
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                child: Text('${weekdays[int.parse(dirtyRoutineContents[index][1])]}', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey,
                                ),),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/*
 * SettingMode
 *   Shows the daily plans
 */
class SettingMode extends StatefulWidget {
  const SettingMode({Key? key}) : super(key: key);

  @override
  _SettingModeState createState() => _SettingModeState();
}

class _SettingModeState extends State<SettingMode> {
  bool isBackKeyActivated = true;
  int selectedIndex = -1;

  void refresh() {
    setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  void openSettingLauguageMode() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => SettingLanguageMode())).then((value) {refresh();});
  }

  void backKeyPressed() {
    if (isBackKeyActivated) {
      FocusScope.of(context).unfocus();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['settings_title']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          color: Colors.white,
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: ListView(
              physics: BouncingScrollPhysics(),
              children: [
                ListTile(
                  leading: Icon(Icons.language_outlined),
                  title: Row(
                    children: [
                      Text(languagePack['settings_language'], style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.centerRight,
                          child: Text('${languagePack[locale2Lanugages[applicationSettings['generalLocale']]]}', style: TextStyle(fontSize: 16, color: Colors.amber[800])),
                        ),
                      )
                    ],
                  ),
                  onTap: () { openSettingLauguageMode(); },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/*
 * SettingLanugageMode
 *   Language steeing
 */
class SettingLanguageMode extends StatefulWidget {
  const SettingLanguageMode({Key? key}) : super(key: key);

  @override
  _SettingLanguageModeState createState() => _SettingLanguageModeState();
}

class _SettingLanguageModeState extends State<SettingLanguageMode> {
  bool isBackKeyActivated = true;
  bool isDirty = false;
  String? selectedLanguages = locale2Lanugages[applicationSettings['generalLocale']!];

  void backKeyPressed() {
    if (isBackKeyActivated) {
      saveSettingFile(applicationSettings);

      if (isDirty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languagePack['rebuild_language_pack_msg']), duration: Duration(seconds: 2),),
        );
      }

      FocusScope.of(context).unfocus();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isBackKeyActivated) { backKeyPressed(); return true; }
        else { return false; }},
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0, backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black,),
            onPressed: backKeyPressed,
            iconSize: 30,
          ),
          title: Text(languagePack['settings_language']),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),

        body: Container(
          color: Colors.white,
          child: Container(
            margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: ListView(
              physics: BouncingScrollPhysics(),
              children: List.generate(languages2Locale.keys.length, (index) => ListTile(
                title: Text(languagePack[languages2Locale.keys.toList()[index]]),
                leading: Radio<String>(
                  value: languages2Locale.keys.toList()[index],
                  groupValue: selectedLanguages,
                  onChanged: (value) {
                    setState(() {
                      isDirty = true;
                      selectedLanguages = value;
                      if (selectedLanguages != null) {
                        applicationSettings['generalLocale'] = languages2Locale[selectedLanguages]!;
                      }
                    });
                  },
                ),
              ),)
            ),
          ),
        ),
      ),
    );
  }
}



/*
 * DailyScheduleMode
 *   Shows the daily plans
 */
class DailyScheduleMode extends StatefulWidget {
  const DailyScheduleMode({Key? key}) : super(key: key);

  @override
  _DailyScheduleModeState createState() => _DailyScheduleModeState();
}

class _DailyScheduleModeState extends State<DailyScheduleMode> {
  List<Widget> schedules = [];
  List<Widget> tasks = [];
  List<Widget> validTasks = [];
  List<DateTime> scheduleDate = [];
  DateTime? currentBackPressTime;
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  int selectedModeIndex = 0;
  bool dragTriggered = false;
  PageController bodyPageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    initializeScheduleTasks();
    selectedModeIndex = 0;
  }

  @override
  void dispose() {
    super.dispose();
    saveAllFiles();
  }

  void initializeSchedules() {
    schedules = [];
    scheduleDate = [];

    // Initializing Scheudules
    List<String> targetDateList = scheduleContents.keys.toList();
    targetDateList.sort((a, b) => b.compareTo(a));
    for (String targetDate in targetDateList) {
      Widget targetWidget = DailyTodoListWidget(dateScheduled: targetDate, todoList: scheduleContents[targetDate]!,);
      schedules.add(targetWidget);
      scheduleDate.add(string2DateTime(targetDate));
    }
  }

  void initializeTasks() {
    tasks = [];
    validTasks = [];
    List<Widget> expiredTasks = [];

    // Initializing Tasks
    if (taskContents.isNotEmpty) {
      taskContents.sort((a, b) => a[2].compareTo(b[2]));
      taskContents.sort((a, b) => a[3].compareTo(b[3]),);
      for (List targetTask in taskContents) {
        Widget targetWidget = TaskWidget(duedate: targetTask[2], taskname: targetTask[0], isChecked: targetTask[3]);
        if (targetTask[2] == dateTime2String(DateTime.now())) {
          tasks.add(targetWidget);
          validTasks.add(targetWidget);
        } else if (string2DateTime(targetTask[2]).isBefore(DateTime.now())) {
          expiredTasks.insert(0, targetWidget);
        } else {
          tasks.add(targetWidget);
          if (string2DateTime(targetTask[1]).isBefore(DateTime.now()) || targetTask[1] == dateTime2String(DateTime.now())) {
            validTasks.add(targetWidget);
          }
        }
      }
    }

    if (taskContents.isEmpty) {
      tasks = [];
    } else if (tasks.isEmpty) {
      tasks = expiredTasks;
    } else {
      tasks = tasks + expiredTasks;
    }
  }

  void initializeScheduleTasks() {
    initializeSchedules();
    initializeTasks();
  }

  void refresh() {
    setState(() { initializeScheduleTasks(); });
  }

  Future<bool> onBackPressed() {
    if (_key.currentState!.isDrawerOpen) {
      _key.currentState!.openEndDrawer();
      return Future.value(false);
    }

    DateTime now = DateTime.now();
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime ?? DateTime.now()) > Duration(seconds: 2)) {
      currentBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languagePack['exit_msg']), duration: Duration(seconds: 2),),
      );
      // showToastMessage('Press back again to exit');
      return Future.value(false);
    }

    saveAllFiles();

    return Future.value(true);
  }

  Widget addTodayScheduleButton({height = 200}) => Container(
    width: double.infinity, height: height.toDouble(),
    padding: EdgeInsets.all(10),
    child: GestureDetector(
      onTap: () { openScheduleManager(DateTime.now()); },
      child: DottedBorder(
        color: Colors.grey,
        borderType: BorderType.RRect,
        radius: Radius.circular(10),
        child: Container(
          alignment: Alignment.center,
          child: Text(languagePack['schedule_manager_empty_msg'], style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
          ),),
        ),
      ),
    ),
  );

  Widget addTaskButton({height = 100}) => GestureDetector(
    onTap: () { openTaskManager(); },
    child: Container(
      padding: EdgeInsets.all(10),
      child: DottedBorder(
        color: Colors.grey,
        borderType: BorderType.RRect,
        radius: Radius.circular(10),
        child: Container(
          alignment: Alignment.center,
          width: double.infinity, height: height.toDouble(),
          child: Text(languagePack['task_manager_empty_msg'], style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey,
          ),),
        ),
      ),
    ),
  );

  Widget generateScheduleMode() {
    return schedules.isEmpty ? addTodayScheduleButton(height: double.infinity) : Container(
      width: double.infinity, height: double.infinity, margin: EdgeInsets.all(5),
      decoration: BoxDecoration( color: Colors.white70 ),
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        itemCount: schedules.length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => { openScheduleManager(scheduleDate[i]) },
          child: schedules[i],
        ),
      ),
    );
  }

  Widget generateTaskMode() {
    return tasks.isEmpty ? addTaskButton(height: double.infinity) : Container(
      width: double.infinity, height: double.infinity, margin: EdgeInsets.all(5),
      decoration: BoxDecoration( color: Colors.white70 ),
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        itemCount: tasks.length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => { openTaskManager() },
          child: tasks[i],
        ),
      ),
    );
  }

  Widget generateDashboardMode() {
    List dashboardWidgets = [];
    String now = dateTime2StringWithoutWeekday(DateTime.now());

    // Generate schedule widget
    if (scheduleContents.keys.contains(now)) {
      List<List> targetSchedules = scheduleContents[now]!.toList();
      dashboardWidgets.add(DailyTodoListWidget(dateScheduled: now, todoList: targetSchedules,));
    } else {
      dashboardWidgets.add( addTodayScheduleButton() );
    }

    // Generate routine widget
    List <String> targetRoutines = [];

    for (int index = 0; index < monthlyRoutineContents.length; index++) {
      if (monthlyRoutineContents[index][1] == getDayFromDateTime(DateTime.now())) {
        targetRoutines.add(monthlyRoutineContents[index][0] + ' (${languagePack['monthly']})');
      } else if (getMonthIntFromDateTime(DateTime.now()) == getMonthSizeFromDateTime(DateTime.now())) {
        if (monthlyRoutineContents[index][1] >= getMonthSizeFromDateTime(DateTime.now())) {
          targetRoutines.add(monthlyRoutineContents[index][0] + ' (${languagePack['end_of_month']})');
        }
      }
    }

    for (int index = 0; index < weeklyRoutineContents.length; index++) {
      if (weekdays[int.parse(weeklyRoutineContents[index][1])] == getWeekDayFromDateTime(DateTime.now())) {
        targetRoutines.add(weeklyRoutineContents[index][0] + ' (${languagePack['weekly']})');
      }
    }

    if (targetRoutines.isNotEmpty) {
      dashboardWidgets.add(RoutineWidget(routineList: targetRoutines,));
    }

    // Generate notification widget
    List <String> targetNotifications = [];

    for (int index = 0; index < notificationContents.length; index++) {
      if (notificationContents[index][1] == dateTime2MonthDayString(DateTime.now())) {
        targetNotifications.add(notificationContents[index][0]);
      }
    }

    if (targetNotifications.isNotEmpty) {
      dashboardWidgets.add(NotificationWidget(notificationList: targetNotifications,));
    }

    // Generate tasks widget
    dashboardWidgets = dashboardWidgets + validTasks;

    if (validTasks.isEmpty) {
      dashboardWidgets.add( addTaskButton() );
    }

    return Container(
      width: double.infinity, height: double.infinity, margin: EdgeInsets.all(5),
      decoration: BoxDecoration( color: Colors.white70 ),
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        itemCount: dashboardWidgets.length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () {
            if (dashboardWidgets[i] is DailyTodoListWidget) {
              openScheduleManager(DateTime.now());
            } else if (dashboardWidgets[i] is TaskWidget) {
              openTaskManager();
            } else if (dashboardWidgets[i] is RoutineWidget) {
              openMonthlyRoutineManager();
            } else if (dashboardWidgets[i] is NotificationWidget) {
              openNotificationManager();
            }
          },
          child: dashboardWidgets[i],
        ),
      ),
    );
  }

  void openScheduleManager(DateTime targetDate) {
    addScheduleInitialDate = targetDate;
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddScheduleMode())).then((value) {refresh();});
  }

  void openTaskManager() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddTaskMode())).then((value) {refresh();});
  }

  void openNotificationManager() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddNotificationMode())).then((value) {refresh();});
  }

  void openMonthlyRoutineManager() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddMonthlyRoutineMode())).then((value) {refresh();});
  }

  void openWeeklyRoutineManager() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddWeeklyRoutineMode())).then((value) {refresh();});
  }

  void openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => SettingMode())).then((value) {refresh();});
  }

  Widget sideMenuBar() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Container(
              alignment: Alignment.center,
              child: Text(languagePack['side_menu_title'], style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ), textAlign: TextAlign.center,),
            ),
            decoration: BoxDecoration(color: Colors.amber[800],),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today_rounded),
            title: Text(languagePack['schedule_manager_title']),
            onTap: () {
              Navigator.of(context).pop();
              openScheduleManager(DateTime.now());
            },
          ),
          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text(languagePack['task_manager_title']),
            onTap: () {
              Navigator.of(context).pop();
              openTaskManager();
            },
          ),
          ListTile(
            leading: Icon(Icons.check),
            title: Text(languagePack['notification_manager_title']),
            onTap: () {
              Navigator.of(context).pop();
              openNotificationManager();
            },
          ),
          ListTile(
            leading: Icon(Icons.access_time),
            title: Text(languagePack['monthly_routine_manager_title']),
            onTap: () {
              Navigator.of(context).pop();
              openMonthlyRoutineManager();
            },
          ),
          ListTile(
            leading: Icon(Icons.access_time),
            title: Text(languagePack['weekly_routine_manager_title']),
            onTap: () {
              Navigator.of(context).pop();
              openWeeklyRoutineManager();
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text(languagePack['settings_title']),
            onTap: () {
              Navigator.of(context).pop();
              openSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onBackPressed,
      child: Scaffold(
          key: _key,
          appBar: AppBar(
            elevation: 0.0, backgroundColor: Colors.white,
            leading: IconButton(
              icon: Icon(Icons.menu, color: Colors.black,),
              onPressed: () { _key.currentState!.openDrawer(); },
              iconSize: 30,
            ),
            title: Text(languagePack['main_title']), titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
          ),

          body: Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.white),
              ),
              child: PageView(
                physics: ClampingScrollPhysics(),
                controller: bodyPageController,
                onPageChanged: (index) { setState(() { selectedModeIndex = index; }); },
                children: [
                  generateDashboardMode(),
                  generateScheduleMode(),
                  generateTaskMode(),
                ],
              ),
            ),
          ),

          drawer: sideMenuBar(),
          drawerEnableOpenDragGesture: false,

          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: languagePack['bottom_menu_dashboard'],
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_rounded),
                label: languagePack['bottom_menu_schedules'],
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_rounded),
                label: languagePack['bottom_menu_tasks'],
              ),
            ],
            elevation: 0.0, currentIndex: selectedModeIndex,
            selectedItemColor: Colors.amber[800], backgroundColor: Colors.white,
            onTap: (index) { setState(() {
              selectedModeIndex = index;
              bodyPageController.animateToPage(
                selectedModeIndex,
                duration: Duration(milliseconds: 400),
                curve: Curves.ease,);
            }); },
          ),
        ),
    );
  }
}


/*
 * DailyTodoListWidget (DailyScheduleMode)
 *   Card widget for each daily plan
 */
class DailyTodoListWidget extends StatefulWidget {
  final String dateScheduled;
  final List<List> todoList;
  const DailyTodoListWidget({Key? key, this.dateScheduled = '', this.todoList = const []}) : super(key: key);

  @override
  _TodoListWidgetState createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<DailyTodoListWidget> {
  List<Widget> generateScheduleWidgets() {
    if (widget.todoList.isEmpty) {
      return [
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
          child: Text('No schedules'),
        ),
      ];
    } else {
      List<List> copiedTodoList = widget.todoList.toList();
      copiedTodoList.sort((a, b) { return a[1].compareTo(b[1]); });

      return List.generate(widget.todoList.length, (i) =>
          Container(
            margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
            child: Text(
              copiedTodoList[i][0],
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500,
                decoration: copiedTodoList[i][1] == '1' ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* Scheduled Date */
            Container(
              margin: EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded),
                  Text('  ${addWeekday2String(widget.dateScheduled)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            Container(
                margin: EdgeInsets.fromLTRB(15, 0, 15, 10),
                child: const Divider()
            ),

            /* list of schedules */
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: generateScheduleWidgets(),
            ),
          ],
        ),
      ),
    );
  }
}


class TaskWidget extends StatefulWidget {
  final String duedate;
  final String taskname;
  final String isChecked;
  const TaskWidget({Key? key, this.duedate = '', this.taskname = '', this.isChecked = '0'}) : super(key: key);

  @override
  _TaskWidgetState createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Card(
        child: Container(
          margin: EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.taskname, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500,
                    color: widget.duedate == dateTime2String(DateTime.now()) ? Colors.red : (string2DateTime(widget.duedate).isBefore(DateTime.now()) ? Colors.grey : Colors.black),
                    decoration: widget.isChecked == '1' ? TextDecoration.lineThrough : TextDecoration.none,
                  ),),
                ),
              ),

              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                  alignment: Alignment.centerRight,
                  child: Text('~ ${addWeekday2String(widget.duedate)}', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey,
                  ),),
                ),
              ),
            ],
          ),
        )
      ),
    );
  }
}


/*
 * Routine Widget
 *   Card widget for routines
 */
class RoutineWidget extends StatefulWidget {
  final List<String> routineList;
  const RoutineWidget({Key? key, this.routineList = const []}) : super(key: key);

  @override
  _RoutineWidgetState createState() => _RoutineWidgetState();
}

class _RoutineWidgetState extends State<RoutineWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* Scheduled Date */
            Container(
              margin: EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: Row(
                children: [
                  Icon(Icons.access_time),
                  Text('  ${languagePack['dashboard_widget_routines_title']}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            Container(
                margin: EdgeInsets.fromLTRB(15, 0, 15, 10),
                child: const Divider()
            ),

            /* list of schedules */
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.routineList.isEmpty ? [
                Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
                  child: Text('No routines'),
                ),
              ] : List.generate( widget.routineList.length, (i) => Container(
                margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
                child: Text(
                  widget.routineList[i],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}


/*
 * Notification Widget
 *   Card widget for notifications
 */
class NotificationWidget extends StatefulWidget {
  final List<String> notificationList;
  const NotificationWidget({Key? key, this.notificationList = const []}) : super(key: key);

  @override
  _NotificationWidgetState createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* Scheduled Date */
            Container(
              margin: EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: Row(
                children: [
                  Icon(Icons.check),
                  Text('  ${languagePack['dashboard_widget_notification_title']}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            Container(
                margin: EdgeInsets.fromLTRB(15, 0, 15, 10),
                child: const Divider()
            ),

            /* list of schedules */
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.notificationList.isEmpty ? [
                Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
                  child: Text('No routines'),
                ),
              ] : List.generate( widget.notificationList.length, (i) => Container(
                margin: EdgeInsets.fromLTRB(15, 0, 15, 20),
                child: Text(
                  widget.notificationList[i],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
