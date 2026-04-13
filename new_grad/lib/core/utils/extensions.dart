extension StringExtensions on String {
  bool get isNullOrEmpty => this.isEmpty;
}

extension ListExtensions<T> on List<T> {
  bool get isNullOrEmpty => isEmpty;
}
