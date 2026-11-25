import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/android_updates.dart';
void main(){
 Map<String,dynamic> manifest()=>{'available':true,'versionCode':3,'versionName':'1.0.2','bytes':1000,'sha256':List.filled(64,'a').join(),'promptEnabled':true};
 test('prompts only for newer enabled builds',(){
  final r=AndroidRelease.parse(manifest())!;
  expect(r.shouldPrompt(2),isTrue);expect(r.shouldPrompt(3),isFalse);expect(r.shouldPrompt(4),isFalse);
  expect(AndroidRelease.parse({...manifest(),'promptEnabled':false})!.shouldPrompt(2),isFalse);
 });
 test('invalid manifests cannot start downloads',(){
  expect(AndroidRelease.parse({'available':false}),isNull);
  expect(AndroidRelease.parse({...manifest(),'sha256':'invalid'}),isNull);
  expect(AndroidRelease.parse({...manifest(),'bytes':201*1024*1024}),isNull);
 });
}
