import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/user_errors.dart';
import 'package:idcolda/api.dart';
void main(){
 test('wrong credentials use app language, not HTTP codes',(){
  expect(friendlyResponse(status:401,path:'/auth/login',detail:'Unauthorized'), 'Invalid email or password.');
  expect(friendlyResponse(status:401,path:'/auth/me'), 'Your session expired. Sign in again.');
  expect(friendlyResponse(status:409,path:'/auth/login',code:'TWO_FACTOR_REQUIRED'),'Enter your authenticator code.');
 });
 test('domain errors and field checks',(){
  expect(friendlyResponse(status:400,path:'/commands/companies/create',detail:'SKU already in use.'),'SKU already exists.');
  expect(friendlyResponse(status:400,path:'/public/register',detail:'Email is already registered.'),'Email already registered.');
  expect(friendlyFieldError('Form.NidBack'),'Select a valid NID back image.');
  expect(friendlyResponse(status:500,path:'/clients',detail:'private exception'),'Service unavailable. Try again later.');
 });
 test('technical details stay out of display',(){
  final e=ApiFailure(401,'Invalid email or password.',null,'private-trace');
  expect(userError(e),'Invalid email or password.');
  expect(e.toString(),isNot(contains('private-trace')));
  expect(userError(StateError('internal value')),isNot(contains('internal value')));
 });
}
