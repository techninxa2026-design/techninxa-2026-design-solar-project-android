import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as ocr;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as bc;
import 'api.dart';
import 'copy.dart';

enum NidSide { front, back }
enum NidEvidence { front, back, uncertain, mixed }

/// Conservative local side classification; not proof of authenticity.
NidEvidence classifyNid(String text,{required bool pdf417}){
 final t=text.toUpperCase().replaceAll(RegExp(r'\s+'),' ');
 final header=t.contains('BANGLADESH')&&RegExp(r'NATIONAL\s+(ID|IDENTITY)|GOVERNMENT').hasMatch(t);
 final dob=RegExp(r'DATE\s+OF\s+BIRTH|DOB').hasMatch(t);
 final name=RegExp(r'\bNAME\b').hasMatch(t);
 final number=RegExp(r'\b(?:NID|ID)\s*(?:NO|NUMBER|N0)?[.:\s]*\d[\d ]{8,20}').hasMatch(t);
 final front=header&&dob&&name&&number&&RegExp(r'\d{4}').hasMatch(t);
 final backLabels=RegExp(r'BLOOD\s*GROUP|ISSUE\s*DATE|PLACE\s*OF\s*BIRTH').allMatches(t).length;
 final mrz=RegExp(r'(?:ID|I<|I)[A-Z<]*BGD[0-9A-Z<]{5,}|BGD[0-9A-Z<]{8,}').hasMatch(t)&&t.contains('<<');
 final back=mrz||(pdf417&&backLabels>=1);
 if(front&&back)return NidEvidence.mixed;
 if(front)return NidEvidence.front;
 if(back)return NidEvidence.back;
 return NidEvidence.uncertain;
}
String? nidSideError(NidSide expected,NidEvidence evidence){
 if(evidence==NidEvidence.mixed)return 'Only one side of the NID may appear in the image. Capture the requested side separately.';
 if(evidence==NidEvidence.uncertain)return 'Could not identify a Bangladesh NID side. Keep the entire card sharp, well lit and free of glare, then try again.';
 if(expected==NidSide.front&&evidence!=NidEvidence.front)return 'This appears to be the back of the NID. Capture the front with the photo and date of birth.';
 if(expected==NidSide.back&&evidence!=NidEvidence.back)return 'This appears to be the front of the NID. Capture the back with the address and barcode.';
 return null;
}
bool nidImageType(Uint8List b)=>b.length>=12&&((b[0]==255&&b[1]==216&&b[2]==255)||(b[0]==137&&b[1]==80&&b[2]==78&&b[3]==71&&b[4]==13&&b[5]==10&&b[6]==26&&b[7]==10)||(b[0]==82&&b[1]==73&&b[2]==70&&b[3]==70&&b[8]==87&&b[9]==69&&b[10]==66&&b[11]==80));
class NidScanPage extends StatefulWidget{
 final NidSide side;
 const NidScanPage({super.key,required this.side});
 @override State<NidScanPage> createState()=>_NidScanPageState();
}
class _NidScanPageState extends State<NidScanPage> with WidgetsBindingObserver{
 CameraController? camera;
 bool busy=false,opening=false,torch=false;
 String? error;
 Upload? accepted;
 int generation=0;
 String get side=>widget.side.name;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
 @override void dispose(){WidgetsBinding.instance.removeObserver(this);generation++;camera?.dispose();super.dispose();}
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if((state==AppLifecycleState.inactive||state==AppLifecycleState.paused)&&camera!=null){
   generation++;final c=camera;camera=null;torch=false;c?.dispose();if(mounted)setState(()=>opening=false);
  }
 }
 Future<void> openCamera()async{
  if(busy||opening||camera!=null)return;
  final g=++generation;setState((){opening=true;error=null;accepted=null;});
  CameraController? next;
  try{
   final cameras=await availableCameras();
   if(cameras.isEmpty)throw StateError('No camera');
   final rear=cameras.where((c)=>c.lensDirection==CameraLensDirection.back).firstOrNull??cameras.first;
   next=CameraController(rear,ResolutionPreset.high,enableAudio:false);
   await next.initialize();
   if(!mounted||g!=generation){await next.dispose();return;}
   setState(()=>camera=next);
  }on CameraException catch(e){await next?.dispose();if(mounted&&g==generation)setState(()=>error=e.code.toLowerCase().contains('access')?'Camera permission denied. Allow camera access in Android Settings, or use Gallery.':'Camera could not start. Try again or use Gallery.');}
  catch(_){await next?.dispose();if(mounted&&g==generation)setState(()=>error='No available camera. Select an image from Gallery.');}
  finally{if(mounted&&g==generation)setState(()=>opening=false);}
 }
 Future<void> flash()async{
  final c=camera;if(c==null||busy)return;
  try{await c.setFlashMode(torch?FlashMode.off:FlashMode.torch);if(mounted&&camera==c)setState(()=>torch=!torch);}
  catch(_){if(mounted)setState(()=>error='The flashlight is unavailable on this camera.');}
 }
 Future<void> capture()async{
  final c=camera;if(c==null||busy||!c.value.isInitialized)return;
  setState((){busy=true;error=null;});
  XFile? shot;
  try{shot=await c.takePicture();await inspect(shot.path);}
  catch(_){if(mounted)setState(()=>error='Could not capture the card. Try again.');}
  finally{if(shot!=null){try{await File(shot.path).delete();}catch(_){}}if(mounted)setState(()=>busy=false);}
 }
 Future<void> gallery()async{
  if(busy||opening)return;setState((){busy=true;error=null;accepted=null;});
  try{
   final result=await FilePicker.pickFiles(type:FileType.image,allowMultiple:false);
   if(!mounted||result==null)return;
   final path=result.files.single.path;
   if(path==null){setState(()=>error='This image could not be opened. Choose a local image.');return;}
   await inspect(path);
  }catch(_){if(mounted)setState(()=>error='Could not open the selected image. Try another image.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> inspect(String path)async{
  final file=File(path);
  if(await file.length()>2000000){if(mounted)setState(()=>error='Image exceeds 2 MB. Select a smaller clear image or retake it.');return;}
  final bytes=await file.readAsBytes();
  if(bytes.length>2000000){if(mounted)setState(()=>error='Image exceeds 2 MB. Choose a smaller clear image.');return;}
  if(!nidImageType(bytes)){if(mounted)setState(()=>error='Choose a valid JPG, PNG or WebP image.');return;}
  final recognizer=ocr.TextRecognizer(script:ocr.TextRecognitionScript.latin);
  final scanner=bc.BarcodeScanner(formats:[bc.BarcodeFormat.pdf417]);
  try{
   final text=await recognizer.processImage(ocr.InputImage.fromFilePath(path));
   final bars=await scanner.processImage(bc.InputImage.fromFilePath(path));
   final issue=nidSideError(widget.side,classifyNid(text.text,pdf417:bars.isNotEmpty));
   if(!mounted)return;
   if(issue!=null){setState(()=>error=issue);return;}
   final ext=bytes[0]==255?'jpg':bytes[0]==137?'png':'webp';
   setState(()=>accepted=Upload('nid-'+side+'.'+ext,bytes));
  }catch(_){if(mounted)setState(()=>error='The image could not be scanned. Use a sharp, supported image and retry.');}
  finally{try{await recognizer.close();}finally{await scanner.close();}}
 }
 Widget preview(){
  final c=camera;
  if(accepted!=null)return Image.memory(accepted!.bytes,fit:BoxFit.contain);
  if(opening)return const Center(child:CircularProgressIndicator());
  if(c==null||!c.value.isInitialized)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.credit_card_rounded,size:70,color:Theme.of(context).colorScheme.primary),const SizedBox(height:12),CopyText('Position the '+side+' side inside the frame')]));
  return Stack(alignment:Alignment.center,children:[
   Center(child:CameraPreview(c)),
   IgnorePointer(child:FractionallySizedBox(widthFactor:.91,child:AspectRatio(aspectRatio:1.59,child:Container(decoration:BoxDecoration(border:Border.all(color:Colors.cyanAccent,width:3),borderRadius:BorderRadius.circular(16))))))
  ]);
 }
 @override Widget build(BuildContext context){
  final colors=Theme.of(context).colorScheme;final c=camera;
  final instruction=widget.side==NidSide.front?'Photo, name, date of birth and ID number must be visible.':'Address, issuing details and barcode or machine-readable lines must be visible.';
  return Scaffold(appBar:AppBar(title:CopyText('Scan NID • '+side.toUpperCase())),body:SafeArea(child:LayoutBuilder(builder:(context,bounds)=>SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CopyText('Bangladesh National ID • '+side,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:6),CopyText(instruction),const SizedBox(height:4),const CopyText('Scan runs on this device. The selected image is submitted only when you save your profile.')
   ])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:SizedBox(height:(bounds.maxHeight*.49).clamp(180.0,480.0).toDouble(),child:ClipRRect(borderRadius:BorderRadius.circular(22),child:ColoredBox(color:colors.surfaceContainerHighest,child:preview())))),
   if(error!=null)Padding(padding:const EdgeInsets.fromLTRB(16,12,16,0),child:Text(error!,style:TextStyle(color:colors.error))),
   if(busy)const Padding(padding:EdgeInsets.all(12),child:LinearProgressIndicator()),
   Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(accepted!=null)...[FilledButton.icon(onPressed:busy?null:()=>Navigator.pop(context,accepted),icon:const Icon(Icons.check_circle_outline),label:CopyText('Use '+side+' image')),TextButton(onPressed:busy?null:()=>setState(()=>accepted=null),child:const CopyText('Retake or select another image'))]
    else ...[FilledButton.icon(onPressed:busy||opening?null:c==null?openCamera:capture,icon:Icon(c==null?Icons.photo_camera_outlined:Icons.document_scanner_outlined),label:CopyText(c==null?'Open camera':'Capture and scan')),if(c!=null)TextButton.icon(onPressed:busy?null:flash,icon:Icon(torch?Icons.flash_off:Icons.flash_on),label:CopyText(torch?'Turn flashlight off':'Turn flashlight on')),OutlinedButton.icon(onPressed:busy||opening?null:gallery,icon:const Icon(Icons.photo_library_outlined),label:const CopyText('Choose from Gallery'))]
   ]))
  ])))));
 }
}
