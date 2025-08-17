abstract class BaseModel {
  Map<String, dynamic> toJson();

  static T? fromJson<T extends BaseModel>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      return fromJson(json);
    } catch (e) {
      return null;
    }
  }
}
