class Metadata {
  String pageContent;
  String txtPath;

  Metadata({
    required this.pageContent,
    required this.txtPath,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) => Metadata(
        pageContent: json["pageContent"],
        txtPath: json["txtPath"],
      );

  Map<String, dynamic> toJson() => {
        "pageContent": pageContent,
        "txtPath": txtPath,
      };
}
