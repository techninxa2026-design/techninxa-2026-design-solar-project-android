import 'package:flutter/material.dart';
import 'copy.dart';
import 'tide_cards.dart';
class AccessFeature{
 final String name,group,description;
 const AccessFeature(this.name,this.group,this.description);
}
// Display metadata only, from MVC OpsPowers and OpsAccessibilityCatalog.
const accessFeatures=<String,AccessFeature>{
  "role.create": AccessFeature("Create organizational roles", "Organization & Accounts", "Define custom organizational roles for your company."),
  "people.assign": AccessFeature("Assign users and territories", "Organization & Accounts", "Create role-bound users and manage your authorized team."),
  "account.create": AccessFeature("Review and create accounts", "Organization & Accounts", "Create initial logins or share application links; review applicants in Application Forms."),
  "department.create": AccessFeature("Create departments", "Organization & Accounts", "Build Sales and Technical department reporting chains."),
  "hierarchy.manage": AccessFeature("Manage organization hierarchy", "Organization & Accounts", "Visualize and securely edit company reporting, positions and team structure."),
  "zone.create": AccessFeature("Create zones (divisions)", "Territories & Branches", "Create a Zone (Division) at the top of the geographic hierarchy."),
  "district.assign": AccessFeature("Manage areas (districts)", "Territories & Branches", "Link an Area (District) to its Zone (Division)."),
  "area.create": AccessFeature("Create thanas", "Territories & Branches", "Create a Thana inside an Area (District)."),
  "branch.create": AccessFeature("Create branches in thanas", "Territories & Branches", "Register a company Branch inside an authorized Thana."),
  "warehouse.create": AccessFeature("Create warehouses", "Inventory & Warehouses", "Register warehouse locations for company stock."),
  "product.create": AccessFeature("Create products", "Inventory & Warehouses", "Create and review solar products in the catalog."),
  "stock.assign": AccessFeature("Assign products to warehouses", "Inventory & Warehouses", "Assign catalog products to your authorized warehouses."),
  "store.manage": AccessFeature("Manage store stock", "Inventory & Warehouses", "Adjust and record stock movements for authorized locations."),
  "task.create": AccessFeature("Create written tasks", "Tasks & Monitoring", "Write and publish operational tasks."),
  "task.assign": AccessFeature("Assign Installer companies and field members", "Tasks & Monitoring", "DA: send tasks to Installer companies; Installer: assign accepted tasks to field workers."),
  "task.monitor.assign": AccessFeature("Assign monitoring members", "Tasks & Monitoring", "Choose a task and appoint monitoring members."),
  "task.report": AccessFeature("Submit monitoring reports", "Tasks & Monitoring", "Open an authorized task to submit monitoring progress."),
  "client.create": AccessFeature("Create and manage clients", "Client Management", "Add and manage client contact details, addresses, service notes and locations."),
  "package.manage": AccessFeature("Manage solar package parameters and packages", "Solar Packages", "Create BESS, inverter and package parameters, priced products and solar packages."),
};
String accessName(String code,{String? serverLabel}){
 final v=serverLabel?.trim()??'';
 if(v.isNotEmpty&&v.toLowerCase()!=code.toLowerCase()&&!RegExp(r'^[a-z0-9_]+(?:[._-][a-z0-9_]+)+$',caseSensitive:false).hasMatch(v))return v;
 return accessFeatures[code]?.name??'Additional accessibility option';
}
String accessGroup(String code)=>accessFeatures[code]?.group??'Other Accessibility';
class AccessibilityChecklist extends StatefulWidget{
 final Map<String,String> choices;final Set<String> selected;
 const AccessibilityChecklist({super.key,required this.choices,required this.selected});
 @override State<AccessibilityChecklist> createState()=>_AccessibilityChecklistState();
}
class _AccessibilityChecklistState extends State<AccessibilityChecklist>{
 late final selected=widget.selected.intersection(widget.choices.keys.toSet());
 String query='';
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final q=query.trim().toLowerCase();
  final groups=<String,List<String>>{};
  for(final code in widget.choices.keys){
   final name=accessName(code,serverLabel:widget.choices[code]);
   if([name,tr(c,name),accessGroup(code),accessFeatures[code]?.description??''].join(' ').toLowerCase().contains(q))(groups[accessGroup(code)]??=[]).add(code);
  }
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TideSurface(tinted:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CopyText('Choose what this person can do',style:t.textTheme.titleMedium),const SizedBox(height:6),
    const CopyText('Only accessibility you are allowed to delegate is listed.'),
    const SizedBox(height:12),Row(children:[Expanded(child:LinearProgressIndicator(value:widget.choices.isEmpty?0:selected.length/widget.choices.length)),const SizedBox(width:12),Text(selected.length.toString()+'/'+widget.choices.length.toString(),style:t.textTheme.titleMedium)]),
    const SizedBox(height:10),FilledButton.icon(onPressed:()=>Navigator.pop(c,Set<String>.of(selected)),icon:const Icon(Icons.check),label:const CopyText('Apply selection')),
   ])),
   const SizedBox(height:12),TextField(decoration:InputDecoration(hintText:tr(c,'Search accessibility'),prefixIcon:const Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v)),
   if(groups.isEmpty)const TideEmpty(message:'No matching accessibility options.'),
   for(final group in groups.entries)...[
    const SizedBox(height:16),TideSection(title:group.key),const SizedBox(height:8),
    TideSurface(padding:const EdgeInsets.all(4),child:Column(children:[
     for(final code in group.value)CheckboxListTile(key:ValueKey('access-'+code),value:selected.contains(code),controlAffinity:ListTileControlAffinity.leading,
      title:CopyText(accessName(code,serverLabel:widget.choices[code]),style:t.textTheme.titleSmall),
      subtitle:accessFeatures[code]==null?null:CopyText(accessFeatures[code]!.description,style:t.textTheme.bodySmall),
      onChanged:(v)=>setState(()=>v==true?selected.add(code):selected.remove(code))),
    ])),
   ],
   const SizedBox(height:12),FilledButton.icon(onPressed:()=>Navigator.pop(c,Set<String>.of(selected)),icon:const Icon(Icons.check),label:const CopyText('Apply selection')),
  ]);
 }
}
