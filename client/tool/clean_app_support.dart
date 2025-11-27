import 'dart:io';

void main() {
  final directoryPath =
      '/Users/mikenimer/Library/Application Support/mydata.tools';
  final directory = Directory(directoryPath);

  if (directory.existsSync()) {
    print('Deleting directory: $directoryPath');
    try {
      directory.deleteSync(recursive: true);
      print('Successfully deleted directory.');
    } catch (e) {
      print('Error deleting directory: $e');
    }
  } else {
    print('Directory does not exist: $directoryPath');
  }
}
