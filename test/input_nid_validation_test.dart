import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/input_validation.dart';
import 'package:idcolda/nid_scan.dart';
void main(){
 test('field-specific validation',(){
  expect(inputError('Email','user@',required:true),isNotNull);
  expect(inputError('Email','user@example.com',required:true),isNull);
  expect(inputError('Form.FullName','A',required:true),isNotNull);
  expect(inputError('Form.WhatsApp','01712345678',required:false),isNotNull);
  expect(inputError('Form.WhatsApp','+8801712345678',required:false),isNull);
  expect(inputError('quantity','0',required:true),isNotNull);
  expect(inputError('confirmPassword','wrong',required:true,password:'correct'),isNotNull);
  expect(inputError('code','12345',required:true,otp:true),isNotNull);
  expect(serverFieldMessage({'Form.Email':'Already in use'},'email'),'Already in use');
 });
 test('front, back, mixed and unknown evidence',(){
  const front='Government of the People Republic of Bangladesh National ID Card Name EXAMPLE Date of Birth 01 Jan 1990 ID No 1234567890';
  const back='Blood Group A+ Issue Date 01 Jan 2020';
  expect(classifyNid(front,pdf417:false),NidEvidence.front);
  expect(classifyNid(back,pdf417:true),NidEvidence.back);
  expect(classifyNid('$front $back',pdf417:true),NidEvidence.mixed);
  expect(classifyNid('Random image',pdf417:false),NidEvidence.uncertain);
  expect(classifyNid('Unrelated barcode',pdf417:true),NidEvidence.uncertain);
  expect(nidSideError(NidSide.front,NidEvidence.back),isNotNull);
  expect(nidSideError(NidSide.back,NidEvidence.front),isNotNull);
  expect(nidSideError(NidSide.back,NidEvidence.back),isNull);
 });
}
