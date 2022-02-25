import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';


// Constants
const Map<String, List<String>> weekdayNames = {
  'en_US': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'ko_KR': ['월', '화', '수', '목', '금', '토', '일'],
};

List<String> defaultWeekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Map<String, String> locale2Lanugages = {
  'en_US': 'english',
  'ko_KR': 'korean',
};

Map<String, String> languages2Locale = {
  'english': 'en_US',
  'korean': 'ko_KR',
};


// Initial settings
Map<String, String> defaultApplicationSettings = {
  'generalLocale': 'ko_KR',
};
Map<String, String> applicationSettings = {};


// Conversion functions
bool string2Bool(String targetString) {
  if (targetString == '1') { return true; }
  return false;
}

String bool2String(bool targetBool) {
  if (targetBool) { return '1'; }
  return '0';
}

DateTime int2DateTime(int year, int month, int day) {
  return DateTime(year, month, day);
}

String dateTime2String(DateTime targetDate) {
  return dateTime2StringWithoutWeekday(targetDate) + ' ' + getWeekDayFromDateTime(targetDate);
}

String dateTime2StringWithoutWeekday(DateTime targetDate) {
  return DateFormat('yyyy-MM-dd').format(targetDate);
}

String addWeekday2String(String targetString) {
  return dateTime2String(DateTime.parse(targetString));
}

String removeWeekday2String(String targetString) {
  return targetString.substring(0, 10);
}

String dateTime2MonthDayString(DateTime targetDate) {
  return DateFormat('M-d').format(targetDate);
}

DateTime string2DateTime(String targetDate) {
  return DateTime.parse(targetDate.substring(0, 10));
}

String getDayFromDateTime(DateTime targetDate) {
  return DateFormat('d').format(targetDate);
}

String getWeekDayFromDateTime(DateTime targetDate) {
  String defaultWeekday = DateFormat('E').format(targetDate);
  int targetWeekdayIndex = defaultWeekdayNames.indexOf(defaultWeekday);
  return weekdayNames[applicationSettings['generalLocale']]![targetWeekdayIndex];
}

int getMonthIntFromDateTime(DateTime targetDate) {
  return targetDate.month.toInt();
}

int getYearIntFromDateTime(DateTime targetDate) {
  return targetDate.year.toInt();
}

int getMonthSizeFromDateTime(DateTime targetDate) {
  if (getMonthIntFromDateTime(targetDate) % 2 == 1) {
    return 31;
  } else if (getMonthIntFromDateTime(targetDate) == 2) {
    if (getYearIntFromDateTime(targetDate) % 4 == 0) { return 29; }
    else { return 28; }
  }
  return 30;
}


// File functions
Future<String> appDataDirname() async {
  String dirname;

  if (Platform.isAndroid || Platform.isIOS) {
    Directory rootDir = await getApplicationDocumentsDirectory();
    dirname = rootDir.path;
  } else {
    dirname = 'assets/SimplePlanner';
  }

  if (! await Directory(dirname).exists()) { await Directory(dirname).create(recursive: true); }
  if (! await Directory('$dirname/schedules').exists()) { await Directory('$dirname/schedules').create(recursive: true); }

  return dirname;
}

String rootDirname() {
  String dirname;

  if (Platform.isAndroid) {
    dirname = '/storage/emulated/0';
  } else {
    dirname = 'assets/SimplePlanner';
  }

  return dirname;
}

String getDateFromFilepath(String filepath) {
  List filetree = filepath.split('/');
  String filename = filetree[filetree.length-1];
  return filename.split('.')[0];
}

Future<String> getFilepathFromDate(String targetDate) async {
  String rootdirname = await appDataDirname();
  return '$rootdirname/$targetDate.txt';
}

Future<File> taskFile() async {
  final path = await appDataDirname();
  return File('$path/tasks.csv');
}

Future<File> notificationFile() async {
  final path = await appDataDirname();
  return File('$path/notifications.csv');
}

Future<File> scheduleFile(String targetDate) async {
  final path = await appDataDirname();
  return File('$path/schedules/$targetDate.txt');
}

Future<File> monthlyRoutineFile() async {
  final path = await appDataDirname();
  return File('$path/monthly_routines.csv');
}

Future<File> weeklyRoutineFile() async {
  final path = await appDataDirname();
  return File('$path/weekly_routines.csv');
}

Future<File> settingFile() async {
  final path = await appDataDirname();
  return File('$path/settings.csv');
}

Future<File> languagePackFile(String targetLocale) async {
  return File('assets/locale/$targetLocale.json');
}


// Read functions
Future<List> listOfScheduleFiles() async {
  final path = await appDataDirname();
  Directory targetDir = Directory('$path/schedules/');

  try {
    return List.from(targetDir.listSync().whereType<File>());
  } catch (e) {
    print('Application root directory ${targetDir.path} not found');
    return [];
  }
}

Future<Map<String, List<List>>> readAllScheduleFiles() async {
  Map<String, List<List>> contents = {};

  for (File targetFile in await listOfScheduleFiles()) {
    String readContent = await targetFile.readAsString();
    List<String> linesplit = readContent.split('\n');
    List<List> commasplit = [];
    for (int index = 0; index < linesplit.length; index++) {
      commasplit.add(linesplit[index].split(','));
    }
    contents[getDateFromFilepath(targetFile.path)] = commasplit;
  }
  return contents;
}

Future<List<List>> readTaskFile() async {
  try {
    File targetFile = await taskFile();
    String readContent = await targetFile.readAsString();
    List<List> result = [];
    if (readContent.isNotEmpty) {
      List<String> tasks = readContent.split('\n');
      for (int index = 0; index < tasks.length; index++) {
        List content = tasks[index].split(',');
        if (content.isNotEmpty) {
          result.add(content);
        }
      }
    }
    return result;
  } catch (e) {
    print('Task file not found');
    return [];
  }
}

Future<List<List>> readNotificationFile() async {
  try {
    File targetFile = await notificationFile();
    String readContent = await targetFile.readAsString();
    List<List> result = [];
    if (readContent.isNotEmpty) {
      List<String> tasks = readContent.split('\n');
      for (int index = 0; index < tasks.length; index++) {
        List content = tasks[index].split(',');
        if (content.isNotEmpty) {
          result.add(content);
        }
      }
    }
    return result;
  } catch (e) {
    print('Notification file not found');
    return [];
  }
}

Future<List<List>> readMonthlyRoutineFile() async {
  try {
    File targetFile = await monthlyRoutineFile();
    String readContent = await targetFile.readAsString();
    List<List> result = [];
    if (readContent.isNotEmpty) {
      List<String> tasks = readContent.split('\n');
      for (int index = 0; index < tasks.length; index++) {
        List content = tasks[index].split(',');
        if (content.isNotEmpty) {
          result.add(content);
        }
      }
    }
    return result;
  } catch (e) {
    print('Monthly routine file not found');
    return [];
  }
}

Future<List<List>> readWeeklyRoutineFile() async {
  try {
    File targetFile = await weeklyRoutineFile();
    String readContent = await targetFile.readAsString();
    List<List> result = [];
    if (readContent.isNotEmpty) {
      List<String> tasks = readContent.split('\n');
      for (int index = 0; index < tasks.length; index++) {
        List content = tasks[index].split(',');
        if (content.isNotEmpty) {
          result.add(content);
        }
      }
    }
    return result;
  } catch (e) {
    print('Monthly routine file not found');
    return [];
  }
}

Future<Map<String, String>> readSettingFile() async {
  try {
    File targetFile = await settingFile();
    String readContent = await targetFile.readAsString();
    Map<String, String> result = {};
    if (readContent.isNotEmpty) {
      List<String> tasks = readContent.split('\n');
      for (int index = 0; index < tasks.length; index++) {
        List content = tasks[index].split(',');
        if (content.isNotEmpty && content.length == 2) {
          result[content[0]] = content[1];
        }
      }
    }
    return result;
  } catch (e) {
    print('Setting file not found');
    return defaultApplicationSettings;
  }
}

Future<Map> readLanguagePackFile(String targetLocale) async {
  try {
    String readContent = await rootBundle.loadString('assets/locale/$targetLocale.json');
    Map result = json.decode(readContent);
    return result;
  } catch (e) {
    print('Cannot assets/locale/$targetLocale.json $e');
    return {};
  }
}


// Save functions
void saveScheduleFile(String targetDate, List<List>? contents) async {
  try {
    File targetFile = await scheduleFile(targetDate);
    if (contents != null) {
      if (contents.isNotEmpty) {
        List<String> commajoin = [];
        for (int index = 0; index < contents.length; index++) {
          commajoin.add(contents[index].join(','));
        }
        targetFile.writeAsString(commajoin.join('\n'));
      }
    } else {
      if (targetFile.existsSync()) { targetFile.delete(); }
    }
  } catch (e) {
    print('[ERROR] Cannot save $targetDate ($e)');
  }
}

void saveTaskFile(List<List> contents) async {
  try {
    File targetFile = await taskFile();
    List<String> assembledContents = [];
    for (int index = 0; index < contents.length; index++) {
      assembledContents.add(contents[index].join(','));
    }
    targetFile.writeAsString(assembledContents.join('\n'));
  } catch (e) {
    print('[ERROR] Cannot save task file ($e)');
  }
}

void saveNotificationFile(List<List> contents) async {
  try {
    File targetFile = await notificationFile();
    List<String> assembledContents = [];
    for (int index = 0; index < contents.length; index++) {
      assembledContents.add(contents[index].join(','));
    }
    targetFile.writeAsString(assembledContents.join('\n'));
  } catch (e) {
    print('[ERROR] Cannot save notification file ($e)');
  }
}

void saveMonthlyRoutineFile(List<List> contents) async {
  try {
    File targetFile = await monthlyRoutineFile();
    List<String> assembledContents = [];
    for (int index = 0; index < contents.length; index++) {
      assembledContents.add(contents[index].join(','));
    }
    targetFile.writeAsString(assembledContents.join('\n'));
  } catch (e) {
    print('[ERROR] Cannot save monthy routine file ($e)');
  }
}

void saveWeeklyRoutineFile(List<List> contents) async {
  try {
    File targetFile = await weeklyRoutineFile();
    List<String> assembledContents = [];
    for (int index = 0; index < contents.length; index++) {
      assembledContents.add(contents[index].join(','));
    }
    targetFile.writeAsString(assembledContents.join('\n'));
  } catch (e) {
    print('[ERROR] Cannot save weekly routine file ($e)');
  }
}

void saveSettingFile(Map<String, String> contents) async {
  try {
    File targetFile = await settingFile();
    List<String> assembledContents = [];
    for (String key in contents.keys) {
      assembledContents.add('$key,${contents[key]}');
    }
    targetFile.writeAsString(assembledContents.join('\n'));
  } catch (e) {
    print('[ERROR] Cannot save weekly routine file ($e)');
  }
}