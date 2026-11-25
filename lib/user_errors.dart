/// Translates server signals into app-owned language. Never displays raw
/// ProblemDetails, HTTP codes, exception text, or trace IDs.
String friendlyFieldError(String key,{String? detail}){
 final name=key.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z]'),'');
 final d=(detail??'').toLowerCase();
 if(name.contains('email')){
  if(RegExp(r'already|duplicate|taken|in use').hasMatch(d))return 'Email already registered.';
  return 'Enter a valid email address.';
 }
 if(name.contains('confirmpassword'))return 'Passwords do not match.';
 if(name.contains('currentpassword'))return 'Check your current password.';
 if(name.contains('password'))return 'Enter a password that meets the security requirements.';
 if(name.contains('whatsapp'))return 'Enter a valid WhatsApp number with country code.';
 if(name.contains('phone')||name=='mobile')return 'Enter a valid phone number.';
 if(name=='fullname')return 'Enter a valid full name.';
 if(name=='nidfront')return 'Select a valid NID front image.';
 if(name=='nidback')return 'Select a valid NID back image.';
 if(name=='slug')return 'Check the company login link.';
 if(name=='logo')return 'Choose a valid company logo.';
 if(name=='productid')return 'Select a valid product.';
 if(name=='warehouseid')return 'Select a valid warehouse.';
 if(name=='clientid')return 'Select a valid client.';
 if(name=='packageid')return 'Select a valid package.';
 if(name=='rolecode'||name=='requestedrolecode')return 'Select a valid role.';
 if(name=='zoneid'||name=='districtid'||name=='areaid'||name=='branchid')return 'Select a valid territory.';
 if(name=='quantity'||name=='delta'||name=='initialquantity')return 'Enter a valid stock quantity.';
 if(name=='unitprice')return 'Enter a valid unit price.';
 if(name=='code'||name=='authenticatorcode')return 'Enter a valid verification code.';
 if(name=='name')return 'Enter a valid name.';
 if(name=='title')return 'Enter a valid title.';
 if(name=='description')return 'Check the description.';
 return 'Check this field and try again.';
}

String friendlyResponse({required int status,required String path,String? code,String? detail,List<String> fields=const [],bool twoFactor=false}){
 final d=(detail??'').toLowerCase();
 final login=path=='/auth/login';
 if(code=='TWO_FACTOR_REQUIRED')return 'Enter your authenticator code.';
 if(status==0)return 'Check your internet connection and try again.';
 if(status==429||d.contains('locked out')||d.contains('temporarily locked'))return 'Too many attempts. Try again later.';
 if(login&&status==401)return twoFactor?'Invalid verification code or sign-in details.':'Invalid email or password.';
 if(status==401)return 'Your session expired. Sign in again.';
 if(status==403)return login?'You do not have access to this company.':'You do not have permission for this action.';
 if(status==404)return path.contains('/public/companies/')?'Company or invitation not found.':'This record could not be found.';
 if(status==413)return 'File is too large. Choose a smaller file.';
 if(status==415)return 'Unsupported file or form format. Try again.';
 if(status>=500)return 'Service unavailable. Try again later.';
 if(status>=300&&status<400)return 'Unable to connect. Try again later.';
 if(status==409)return 'This record has changed. Refresh and try again.';
 if(RegExp(r'email.*(already|in use|belongs|registered|duplicate)|duplicate.*email').hasMatch(d))return 'Email already registered.';
 if(d.contains('sku')&&(d.contains('already')||d.contains('conflict')))return 'SKU already exists.';
 if(d.contains('current password is incorrect')&&d.contains('or'))return 'Check your current password and new password requirements.';
 if(d.contains('current password is incorrect')||d.contains('password mismatch'))return 'Invalid current password.';
 if(d.contains('password')&&d.contains('match')&&!d.contains('requirements'))return 'Passwords do not match.';
 if(d.contains('password')&&(d.contains('symbol')||d.contains('security')||d.contains('strong')||d.contains('character')))return 'Choose a password with at least 6 characters and a symbol.';
 if(d.contains('already')&&d.contains('role name'))return 'Role name already exists.';
 if(d.contains('department')&&(d.contains('duplicate')||d.contains('already exists')))return 'Department name already exists.';
 if(d.contains('parameter')&&d.contains('already exists'))return 'Parameter already exists.';
 if(d.contains('product already assigned'))return 'Product already assigned.';
 if(d.contains('insufficient')&&d.contains('quantity'))return 'Stock quantity is insufficient or exceeds the allowed limit.';
 if(d.contains('warehouse')&&d.contains('initial quantity'))return 'Select a warehouse for the initial stock.';
 if(d.contains('installation date')&&d.contains('one year'))return 'Choose an installation date from today to one year ahead.';
 if(d.contains('rejection reason'))return 'Enter a reason for rejecting this request.';
 if(d.contains('otp')&&(d.contains('invalid')||d.contains('incorrect')||d.contains('expired')))return 'Invalid or expired OTP. Check the code and try again.';
 if(d.contains('circular')||d.contains('report to itself'))return 'This move would create an invalid reporting structure.';
 if(d.contains('territory')||d.contains('district')||d.contains('zone'))return 'Check the selected territory and its assigned parent.';
 if(d.contains('already reviewed'))return 'This application has already been reviewed.';
 if(d.contains('installer')&&d.contains('already'))return 'This installer already has an assignment.';
 if(d.contains('login url')||d.contains('login link'))return 'Company login link is already in use or invalid.';
 if(fields.length==1&&fields.first.isNotEmpty)return friendlyFieldError(fields.first,detail:detail);
 if(fields.isNotEmpty)return 'Check the highlighted fields and try again.';
 if(path.contains('change-password'))return 'Check your current password and new password requirements.';
 if(login)return 'Unable to sign in. Check your details and try again.';
 return 'Unable to complete this action. Check your details and try again.';
}
