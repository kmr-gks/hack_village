import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:http_parser/http_parser.dart';
import 'storage_helper.dart';

Future<Map<String, dynamic>?> analyzeImage(String imageUrl) async {
  final uri = Uri.parse(
    'https://dietitian-backend--main-919605860399.us-central1.run.app/',
  );
  final dio = Dio(BaseOptions(baseUrl: uri.toString()));
  // 1. 画像をダウンロード（bytes と Content-Type を取得）
  final res = await dio.get<List<int>>(
    imageUrl,
    options: Options(responseType: ResponseType.bytes),
  );

  final bytes = res.data!;
  final contentType =
      res.headers.value('content-type') ?? 'application/octet-stream';

  // URL 末尾からファイル名を推定
  final fileName = p.basename(Uri.parse(imageUrl).path);

  // 2. FormData 作成
  final form = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      bytes,
      filename: fileName.isEmpty ? 'upload.bin' : fileName,
      contentType: MediaType.parse(contentType),
    ),
  });

  // 2.5 ユーザーデータの取得
  final userData = await StorageHelper.loadData('google_auth_data');
  if (userData == null) {
    print('ユーザーデータが存在しません');
    return null; // または適切なエラー処理
  }
  final accessToken = userData['accessToken'];
  if (accessToken == null || accessToken.isEmpty) {
    print('accessToken が取得できませんでした');
    return null; // または適切なエラー処理
  }

  // 3. FastAPI へアップロード
  final resp = await dio.post(
    '/',
    data: form,
    options: Options(
      contentType: 'multipart/form-data',
      headers: {'Authorization': 'Bearer $accessToken'},
    ),
    onSendProgress:
        (sent, total) =>
            print('upload ${(sent / total * 100).toStringAsFixed(1)} %'),
  );

  print('▶︎ status=${resp.statusCode}');
  print('▶︎ body=${resp.data}');

  final response = resp.data;

  //エラーハンドリング
  if (response is Map<String, dynamic> && response.containsKey('error')) {
    print('Error: ${response['error']}');
    return null;
  }
  if (response is Map<String, dynamic> && response.containsKey('result')) {
    return response['result'] as Map<String, dynamic>;
  }

  return resp.data;
}
