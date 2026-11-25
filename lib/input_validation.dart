String fieldKey(String key)=>key.toLowerCase().replaceFirst(RegExp(r'^form\.'),'').replaceAll(RegExp(r'[^a-z0-9]'),'');
String? inputError(String key,String? value,{required bool required,String? title,bool newPassword=false,String? password,bool otp=false}){
 final n=fieldKey(key),raw=value??'',v=raw.trim(),name=title??key;
 if(v.isEmpty)return required?'Enter '+name+'.':null;
 if(n.contains('email')&&(v.length>254||!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)))return 'Enter a valid email address, e.g. name@example.com.';
 if(n=='fullname'&&(v.length<2||v.length>150))return 'Full name must contain 2–150 characters.';
 if(n=='confirmpassword'&&password!=null&&raw!=password)return 'Passwords do not match.';
 if((n=='newpassword'||newPassword&&n=='password')&&(raw.length<6||raw.length>128))return 'Password must contain 6–128 characters.';
 if(otp&&!RegExp(r'^\d{6}$').hasMatch(v))return 'Enter the six-digit verification code.';
 if(n=='whatsapp'&&!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v))return 'Enter WhatsApp number with country code, e.g. +8801712345678.';
 if(['phone','mobile','customerphone','customermobile'].contains(n)&&(!RegExp(r'^\+?[\d ()-]{7,35}$').hasMatch(v)||v.replaceAll(RegExp(r'\D'),'').length<7))return 'Enter a valid phone number.';
 if(n=='website'){final u=Uri.tryParse(v);if(u==null||!['http','https'].contains(u.scheme)||u.host.isEmpty)return 'Enter a full website URL, e.g. https://example.com.';}
 if(n=='gpslocationurl'){final u=Uri.tryParse(v);if(u==null||u.scheme!='https'||u.userInfo.isNotEmpty||!['maps.app.goo.gl','goo.gl','google.com','www.google.com','maps.google.com'].contains(u.host))return 'Enter a valid HTTPS Google Maps link.';}
 if(n=='quantity'&&(int.tryParse(v)==null||int.parse(v)<1||int.parse(v)>1000000))return 'Enter a whole quantity from 1 to 1,000,000.';
 if(n=='delta'&&(int.tryParse(v)==null||int.parse(v)==0))return 'Enter a non-zero whole stock adjustment.';
 if(n.endsWith('date')&&DateTime.tryParse(v)==null)return 'Choose a valid date.';
 return null;
}
String? serverFieldMessage(Map<String,String> errors,String key){
 for(final e in errors.entries){if(fieldKey(e.key)==fieldKey(key))return e.value;}
 return null;
}
