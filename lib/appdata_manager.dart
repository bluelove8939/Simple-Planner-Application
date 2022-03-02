import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}


// Constants and global variables
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

enum progressStatus {progress, end, error}
String? logMessage;


// Initial settings
Map<String, String> defaultApplicationSettings = {
  'loginInitialized': 'false',
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
  return dateTime2String(DateTime.parse(removeWeekday2String(targetString)));
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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
    String readContent = await targetFile.readAsString(encoding: utf8);
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

    for (String settingsKey in defaultApplicationSettings.keys) {
      if (!result.containsKey(settingsKey)) {
        result[settingsKey] = defaultApplicationSettings[settingsKey]!;
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
        targetFile.writeAsString(commajoin.join('\n'), encoding: utf8);
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
    targetFile.writeAsString(assembledContents.join('\n'), encoding: utf8);
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
    targetFile.writeAsString(assembledContents.join('\n'), encoding: utf8);
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
    targetFile.writeAsString(assembledContents.join('\n'), encoding: utf8);
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
    targetFile.writeAsString(assembledContents.join('\n'), encoding: utf8);
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


// Google Drive API functions
Future<bool> backupAllFiles(drive.DriveApi? driveApi) async {
  try {
    bool totalResult = true;

    if (driveApi != null) {
      drive.FileList fileList = await driveApi.files.list(spaces: 'drive', q: "trashed = false");
      List<drive.File>? files = fileList.files;
      String backupDate = DateTime.now().toString();

      String rootID = "";
      String targetDirID = "";
      String scheduleDirID = "";

      // Initialize root directory
      bool initialized = false;
      if (files != null) {
        for (int index = 0; index < fileList.files!.length; index++) {
          if (files[index].mimeType == "application/vnd.google-apps.folder" && files[index].name == 'Simple Planner Backups') {
            initialized = true;
            rootID = files[index].id!;
          }
        }
      }

      var rootDirFile = drive.File();
      rootDirFile.name = "Simple Planner Backups";
      rootDirFile.mimeType = 'application/vnd.google-apps.folder';
      if (!initialized) {
        final result = await driveApi.files.create(rootDirFile);
        rootID = result.id!;
        print("generated root dir $rootID");
      }

      // Remove first target directory if there's more than 10 directories
      final foundTargetDirNames = await driveApi.files.list(spaces: 'drive', q: "'$rootID' in parents and trashed = false",);
      if (foundTargetDirNames.files != null && foundTargetDirNames.files!.length > 9) {
        List fileNames = foundTargetDirNames.files!;
        fileNames.sort((a, b) => a.name!.compareTo(b.name!));
        while (fileNames.length > 9) {
          driveApi.files.delete(fileNames[0].id!);
          print('delete target directory (${fileNames[0].id!}) => current dirlist length: ${fileNames.length}');
          fileNames.removeAt(0);
        }
      }

      // Initialize target directory
      var targetDirFile = drive.File();
      targetDirFile.name = backupDate;
      targetDirFile.mimeType = 'application/vnd.google-apps.folder';
      targetDirFile.parents = [rootID];
      final targetDir = await driveApi.files.create(targetDirFile);
      targetDirID = targetDir.id!;
      print("generated target dir $targetDirID");

      // Initialize schedule directory
      var scheduleDirFile = drive.File();
      scheduleDirFile.name = "Schedules";
      scheduleDirFile.mimeType = 'application/vnd.google-apps.folder';
      scheduleDirFile.parents = [targetDirID];
      final scheduleDir = await driveApi.files.create(scheduleDirFile);
      scheduleDirID = scheduleDir.id!;
      print("generated schedule dir $scheduleDirID");

      // Backup schedule files
      for (File targetFile in await listOfScheduleFiles()) {
        bool result = await backupTargetFile(targetFile, 'txt', driveApi, scheduleDirID);
        if (!result) { totalResult = false; }
      }

      // Backup task file
      File targetFile = await taskFile();
      bool result = await backupTargetFile(targetFile, 'csv', driveApi, targetDirID);
      if (!result) { totalResult = false; }

      // Backup notification file
      targetFile = await notificationFile();
      result = await backupTargetFile(targetFile, 'csv', driveApi, targetDirID);
      if (!result) { totalResult = false; }

      // Backup monthly routine file
      targetFile = await monthlyRoutineFile();
      result = await backupTargetFile(targetFile, 'csv', driveApi, targetDirID);
      if (!result) { totalResult = false; }

      // Backup weekly routine file
      targetFile = await weeklyRoutineFile();
      result = await backupTargetFile(targetFile, 'csv', driveApi, targetDirID);
      if (!result) { totalResult = false; }
    } else {
      totalResult = false;
    }

    return totalResult;
  } catch (e) {
    print("backup error occurred ($e)");
    return false;
  }
}

Future<bool> backupTargetFile(File targetFile, String extension, drive.DriveApi driveApi, String parentDirID) async {
  try {
    var backupFile = drive.File();
    String contents = await targetFile.readAsString(encoding: utf8);
    List<int> encodedContents = utf8.encode(contents);
    backupFile.name = "${getDateFromFilepath(targetFile.path)}.$extension";
    backupFile.parents = [parentDirID];
    Stream<List<int>> mediaStream = Future.value(encodedContents).asStream().asBroadcastStream();
    var media = drive.Media(mediaStream, encodedContents.length, contentType: "text/plain; charset=UTF-8");
    final result = await driveApi.files.create(backupFile, uploadMedia: media,);
    print("Backup file ${targetFile.path} as file id  ${result.id}");

    return true;
  } catch(e) {
    print('error occurred on generating back up of ${targetFile.path} ($e)');
    return false;
  }
}

Future<List<String>> backupTargetDirList(drive.DriveApi? driveApi) async {
  try {
    List<String> result = [];

    if (driveApi != null) {
      final foundRootDir = await driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = 'Simple Planner Backups' and trashed = false",
        $fields: "files(id, name)",
      );

      String rootDirID = foundRootDir.files!.first.id!;

      final foundTargetDir = await driveApi.files.list(
        spaces: 'drive',
        q: "'$rootDirID' in parents and trashed = false",
      );

      for (drive.File targetDirFile in foundTargetDir.files!) {
        result.add(targetDirFile.name!);
      }

      result.sort((a, b) => b.compareTo(a));
    }

    return result;
  } catch (e) {
    print('error occurred on generating list of backups ($e)');
    return [];
  }
}

Future<bool> restoreAllFiles(drive.DriveApi? driveApi, String targetDirName, GoogleAuthClient? authenticateClient) async {
  try {
    if (driveApi != null) {
      final foundTargetDirFiles = await driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$targetDirName' and trashed = false",
        $fields: "files(id, name)",
      );

      String targetDirID = foundTargetDirFiles.files!.first.id!;

      final foundScheduleDirFiles = await driveApi.files.list(
        spaces: 'drive',
        q: "'$targetDirID' in parents and trashed = false and name = 'Schedules'",
      );

      // Reading schedule files
      String scheduleDirID = foundScheduleDirFiles.files!.first.id!;

      final foundScheduleFiles = await driveApi.files.list(
        spaces: 'drive',
        q: "'$scheduleDirID' in parents and trashed = false",
      );

      for (drive.File targetScheduleDriveFile in foundScheduleFiles.files!) {
        String readScheduleContent = await downloadRequest(targetScheduleDriveFile.id!, authenticateClient);
        String targetScheduleFileName = targetScheduleDriveFile.name!;
        File targetScheduleFile = await scheduleFile(getDateFromFilepath(targetScheduleFileName));
        targetScheduleFile.writeAsString(readScheduleContent, encoding: utf8);
      }

      // Reading tasks file
      final foundTaskFiles = await driveApi.files.list(spaces: 'drive', q: "'$targetDirID' in parents and trashed = false and name = 'tasks.csv'",);
      String taskFilesID = foundTaskFiles.files!.first.id!;
      String readTaskContent = await downloadRequest(taskFilesID, authenticateClient);
      File targetTaskFile = await taskFile();
      targetTaskFile.writeAsString(readTaskContent, encoding: utf8);

      // Reading notification file
      final foundNotificationFile = await driveApi.files.list(spaces: 'drive', q: "'$targetDirID' in parents and trashed = false and name = 'notifications.csv'",);
      String notificationFileID = foundNotificationFile.files!.first.id!;
      String readNotificationContent = await downloadRequest(notificationFileID, authenticateClient);
      File targetNotificationFile = await notificationFile();
      targetNotificationFile.writeAsString(readNotificationContent, encoding: utf8);

      // Reading monthly routine file
      final foundMonthlyRoutineFile = await driveApi.files.list(spaces: 'drive', q: "'$targetDirID' in parents and trashed = false and name = 'monthly_routines.csv'",);
      String monthlyRoutineFilesID = foundMonthlyRoutineFile.files!.first.id!;
      String readMonthlyRoutineContent = await downloadRequest(monthlyRoutineFilesID, authenticateClient);
      File targetMonthlyRoutineFile = await monthlyRoutineFile();
      targetMonthlyRoutineFile.writeAsString(readMonthlyRoutineContent, encoding: utf8);

      // Reading weekly routine file
      final foundWeeklyRoutineFile = await driveApi.files.list(spaces: 'drive', q: "'$targetDirID' in parents and trashed = false and name = 'weekly_routines.csv'",);
      String weeklyRoutineFilesID = foundWeeklyRoutineFile.files!.first.id!;
      String readWeeklyRoutineContent = await downloadRequest(weeklyRoutineFilesID, authenticateClient);
      File targetWeeklyRoutineFile = await weeklyRoutineFile();
      targetWeeklyRoutineFile.writeAsString(readWeeklyRoutineContent, encoding: utf8);
    }

    return true;
  } catch(e) {
    print('restoration error occurred ($e)');
    return false;
  }
}

Future<String> downloadRequest(String fileID, GoogleAuthClient? authenticateClient) async {
  try {
    if (authenticateClient != null) {
      http.Response req = await authenticateClient.get(Uri.parse("https://www.googleapis.com/drive/v3/files/$fileID?alt=media"),);
      print('======= $fileID: ${utf8.decode(req.bodyBytes)}');
      return utf8.decode(req.bodyBytes);
    }
    return '';
  } catch(e) {
    print('download request on file ($fileID) failed ($e)');
    return '';
  }
}