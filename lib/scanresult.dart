class ScanResult {
  final ScanResultType type;
  final String data;

  const ScanResult(this.type, this.data);
  const ScanResult.uri(this.data) : type = ScanResultType.uri;
  const ScanResult.raw(this.data) : type = ScanResultType.raw;
}

enum ScanResultType {
  uri,
  raw,
}