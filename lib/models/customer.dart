class Customer {
 final int? id; final String name, phone, zalo, address, source, stage, need, note, createdAt, updatedAt; final double budget;
 const Customer({this.id, required this.name, this.phone='', this.zalo='', this.address='', this.source='Khác', this.stage='Khách mới', this.need='', this.budget=0, this.note='', required this.createdAt, required this.updatedAt});
 Map<String,Object?> toMap()=>{'id':id,'name':name,'phone':phone,'zalo':zalo,'address':address,'source':source,'stage':stage,'need':need,'budget':budget,'note':note,'created_at':createdAt,'updated_at':updatedAt};
 factory Customer.fromMap(Map<String,Object?> m)=>Customer(id:m['id'] as int?,name:(m['name']??'') as String,phone:(m['phone']??'') as String,zalo:(m['zalo']??'') as String,address:(m['address']??'') as String,source:(m['source']??'Khác') as String,stage:(m['stage']??'Khách mới') as String,need:(m['need']??'') as String,budget:((m['budget']??0) as num).toDouble(),note:(m['note']??'') as String,createdAt:(m['created_at']??'') as String,updatedAt:(m['updated_at']??'') as String);
}
