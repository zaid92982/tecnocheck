
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TecnoCheckApp(prefs: prefs));
}

class TecnoCheckApp extends StatefulWidget {
  final SharedPreferences prefs;
  const TecnoCheckApp({super.key, required this.prefs});
  @override
  State<TecnoCheckApp> createState() => _TecnoCheckAppState();
}
class _TecnoCheckAppState extends State<TecnoCheckApp> {
  bool dark = false;
  @override
  void initState() { super.initState(); dark = widget.prefs.getBool('dark') ?? false; }
  void toggleTheme() { setState(() => dark = !dark); widget.prefs.setBool('dark', dark); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'TecnoCheck',
    theme: _theme(false), darkTheme: _theme(true), themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: HomeShell(prefs: widget.prefs, dark: dark, onTheme: toggleTheme),
  );
  ThemeData _theme(bool isDark) {
    const navy = Color(0xFF0A1931), turquoise = Color(0xFF00C2D3);
    final scheme = ColorScheme.fromSeed(seedColor: turquoise, brightness: isDark ? Brightness.dark : Brightness.light,
      primary: navy, secondary: turquoise, surface: isDark ? const Color(0xFF17243A) : const Color(0xFFF8FAFC));
    return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: isDark ? const Color(0xFF0D1728) : const Color(0xFFF2F6FA),
      appBarTheme: AppBarTheme(backgroundColor: isDark ? const Color(0xFF111E32) : Colors.white, foregroundColor: isDark ? Colors.white : navy, elevation: 0),
      cardTheme: CardThemeData(color: isDark ? const Color(0xFF17243A) : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE5EAF0)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: isDark ? const Color(0xFF202F46) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    );
  }
}

class Device {
  final Map<String,dynamic> data;
  Device(this.data);
  String get id => data['id'];
  String get name => data['nombre'];
  String get category => data['categoria'];
  int get price => (data['precio'] as num).round();
  Map<String,dynamic> get detail => Map<String,dynamic>.from(data['detalle'] ?? {});
  Map<String,dynamic> get uses => Map<String,dynamic>.from(data['usos'] ?? {});
  Map<String,dynamic> get reasons => Map<String,dynamic>.from(data['razones'] ?? {});
  String get icon => category == 'celulares' ? '📱' : category == 'laptops' ? '💻' : category == 'relojes' ? '⌚' : '▣';
}
String money(num n) => '\$${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
const categories = {'celulares':'Celulares','laptops':'Laptops','relojes':'Relojes','tablets':'Tablets'};
const navy = Color(0xFF0A1931), aqua = Color(0xFF00C2D3);

class HomeShell extends StatefulWidget {
  final SharedPreferences prefs; final bool dark; final VoidCallback onTheme;
  const HomeShell({super.key, required this.prefs, required this.dark, required this.onTheme});
  @override State<HomeShell> createState()=>_HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int page=0; bool logged=false, register=false; String username='';
  final nameCtrl=TextEditingController(), emailCtrl=TextEditingController(), passCtrl=TextEditingController();
  List<Device> devices=[]; final Set<String> selected={};
  @override void initState(){super.initState(); _load(); }
  Future<void> _load() async {
    final raw=await rootBundle.loadString('assets/catalogo.json');
    final list=(jsonDecode(raw) as List).cast<Map<String,dynamic>>();
    setState(()=>devices=list.map(Device.new).toList());
    username=widget.prefs.getString('user_name')??'';
    logged=widget.prefs.getBool('logged')??false;
    if(mounted)setState((){});
  }
  @override void dispose(){nameCtrl.dispose();emailCtrl.dispose();passCtrl.dispose();super.dispose();}
  void _login() async {
    final email=emailCtrl.text.trim().toLowerCase(), pass=passCtrl.text;
    if(!email.contains('@')||pass.length<6){_msg('Escribe un correo válido y una contraseña de al menos 6 caracteres.');return;}
    final saved=widget.prefs.getString('account_$email');
    if(register){
      if(saved!=null){_msg('Ese correo ya tiene una cuenta.');return;}
      username=nameCtrl.text.trim().isEmpty?email.split('@').first:nameCtrl.text.trim();
      await widget.prefs.setString('account_$email', pass);
      await widget.prefs.setString('name_$email',username);
    } else {
      if(saved==null||saved!=pass){_msg('No encontramos la cuenta o la contraseña es incorrecta.');return;}
      username=widget.prefs.getString('name_$email')??email.split('@').first;
    }
    await widget.prefs.setBool('logged',true); await widget.prefs.setString('user_name',username);
    setState(()=>logged=true);
  }
  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  void _logout() async {await widget.prefs.setBool('logged',false);setState(()=>logged=false);}
  @override Widget build(BuildContext context) {
    if(devices.isEmpty)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(!logged)return _loginPage();
    final titles=['Inicio','Comparador','Presupuesto','Escáner','Talleres'];
    final pages=[_home(),_compare(),_budget(),_scanner(),_workshops()];
    return Scaffold(
      appBar: AppBar(title: Row(children:[Image.asset('assets/logo-tecnocheck.png',height:34,width:42,fit:BoxFit.contain),const SizedBox(width:8),const Text('TECNOCHECK',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.1))]),
        actions:[IconButton(tooltip:widget.dark?'Modo claro':'Modo oscuro',onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode)),PopupMenuButton<String>(onSelected:(v){if(v=='salir')_logout();},itemBuilder:(_)=>[PopupMenuItem(value:'salir',child:Text('Cerrar sesión · $username'))])]),
      body: SafeArea(child:IndexedStack(index:page,children:pages)),
      bottomNavigationBar: NavigationBar(selectedIndex:page,onDestinationSelected:(v)=>setState(()=>page=v),destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Inicio'),
        NavigationDestination(icon:Icon(Icons.compare_arrows),label:'Comparar'),
        NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'Presupuesto'),
        NavigationDestination(icon:Icon(Icons.document_scanner_outlined),label:'Escáner'),
        NavigationDestination(icon:Icon(Icons.handyman_outlined),label:'Talleres'),
      ]),
    );
  }
  Widget _loginPage()=>Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Card(child:Padding(padding:const EdgeInsets.all(26),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Image.asset('assets/logo-tecnocheck.png',height:85),const SizedBox(height:16),Text(register?'Crea tu cuenta':'Entra a TecnoCheck',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('Tecnología fácil, compra segura.'),const SizedBox(height:22),
    if(register)TextField(controller:nameCtrl,decoration:const InputDecoration(labelText:'Nombre')),
    if(register)const SizedBox(height:12),
    TextField(controller:emailCtrl,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Correo electrónico')),const SizedBox(height:12),
    TextField(controller:passCtrl,obscureText:true,decoration:const InputDecoration(labelText:'Contraseña')),const SizedBox(height:20),
    ElevatedButton(onPressed:_login,child:Text(register?'Crear cuenta':'Entrar')),TextButton(onPressed:()=>setState(()=>register=!register),child:Text(register?'Ya tengo cuenta':'Crear cuenta')),
    const Text('Cuenta local de demostración. No se sincroniza entre dispositivos.',style:TextStyle(fontSize:12,color:Colors.grey))
  ])))))));
  Widget _wrap(String title,String subtitle,Widget child)=>SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,18,18,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(subtitle,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)),const SizedBox(height:20),child
  ]));
  Widget _home()=>_wrap('Tecnología fácil, compra segura.','Bienvenido(a), $username. Compara dispositivos y toma decisiones de compra informadas.',Column(children:[
    Card(color:navy,child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('COMPRA CON CONFIANZA',style:TextStyle(color:aqua,fontWeight:FontWeight.bold,letterSpacing:1.3)),const SizedBox(height:10),const Text('Encuentra el dispositivo que realmente necesitas.',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:10),const Text('Consulta fichas, compara precios de referencia y revisa equipos antes de pagar.',style:TextStyle(color:Colors.white70))
    ]))),
    const SizedBox(height:14),
    GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.35,children:[
      _homeTile(Icons.compare_arrows,'Comparador','Compara hasta 3 equipos',1),_homeTile(Icons.savings,'Presupuesto','Encuentra opciones',2),_homeTile(Icons.document_scanner,'Escáner','Checklist de revisión',3),_homeTile(Icons.handyman,'Talleres','Consejos y servicios',4)
    ]),
    const SizedBox(height:16),const Text('¿Qué significan las especificaciones?',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    _info('RAM','Memoria que ayuda a mantener varias aplicaciones abiertas.'),_info('Hz','Frecuencia de actualización: puede hacer que la pantalla se sienta más fluida.'),_info('mAh','Capacidad de batería; no equivale directamente a horas de duración.')
  ]));
  Widget _homeTile(IconData icon,String title,String sub,int target)=>Card(child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>setState(()=>page=target),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:aqua,size:28),const SizedBox(height:9),Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),Text(sub,style:const TextStyle(fontSize:12,color:Colors.grey))]))));
  Widget _info(String a,String b)=>ListTile(title:Text(a,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(b));
  Widget _categoryPicker(String value,ValueChanged<String> onChanged)=>DropdownButtonFormField<String>(value:value,decoration:const InputDecoration(labelText:'Tipo de dispositivo'),items:[const DropdownMenuItem(value:'todos',child:Text('Todos los dispositivos')),...categories.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value)))],onChanged:(v){if(v!=null)onChanged(v);});
  Widget _deviceCard(Device d,{bool chosen=false,VoidCallback? onTap})=>Card(child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Text(d.icon,style:const TextStyle(fontSize:30)),const Spacer(),if(chosen)const Icon(Icons.check_circle,color:aqua)]),const SizedBox(height:8),Text(d.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),Text(money(d.price),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:22,color:aqua)),Text(d.detail['tipo']??'Nuevo',style:const TextStyle(fontSize:12,color:Colors.grey)),const SizedBox(height:8),
    _spec('Batería',d.detail['humano']?['bateria']??'—'),_spec('Memoria',d.detail['humano']?['apps']??'—'),_spec('Pantalla',d.detail['humano']?['pantalla']??'—'),Text(d.detail['semaforo']?['texto']??'',style:const TextStyle(fontSize:12))
  ]))));
  Widget _spec(String a,String b)=>Padding(padding:const EdgeInsets.only(top:4),child:Text('$a: $b',style:const TextStyle(fontSize:12)));
  Widget _compare(){
    String cat='celulares';
    return StatefulBuilder(builder:(context,setLocal){
      final list=devices.where((d)=>d.category==cat).toList();
      final chosen=devices.where((d)=>selected.contains(d.id)&&d.category==cat).toList();
      return _wrap('Comparador de dispositivos','Selecciona hasta tres equipos de la misma categoría para revisar sus diferencias.',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _categoryPicker(cat,(v){setLocal(()=>cat=v);}),
        const SizedBox(height:12),Text('${chosen.length} de 3 seleccionados',style:const TextStyle(fontWeight:FontWeight.bold)),
        GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.75,crossAxisSpacing:10,mainAxisSpacing:10),itemCount:list.length,itemBuilder:(c,i){final d=list[i];return _deviceCard(d,chosen:selected.contains(d.id),onTap:(){
          setState(() {
            if (selected.contains(d.id)) { selected.remove(d.id); }
            else if (selected.length < 3) { selected.add(d.id); }
            else { _msg('Solo puedes comparar hasta 3 dispositivos.'); }
          });
          setLocal((){});
        });}),
        if(chosen.length>=2)...[const SizedBox(height:16),Card(color:navy,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('VEREDICTO HONESTO',style:TextStyle(color:aqua,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('Mejor precio: ${chosen.reduce((a,b)=>a.price<b.price?a:b).name}',style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.bold)),Text('Más económico: ${money(chosen.map((e)=>e.price).reduce((a,b)=>a<b?a:b))}',style:const TextStyle(color:Colors.white70)),const SizedBox(height:8),...chosen.map((d)=>Text('${d.name}: ${d.detail['humano']?['fallas']??'Revisa garantía'}',style:const TextStyle(color:Colors.white)))
        ])))],
        TextButton(onPressed:()=>setState(()=>selected.clear()),child:const Text('Limpiar selección'))
      ]);
    });
  }
  Widget _budget(){
    final amount=TextEditingController();String cat='todos',use='escuela';List<Device> result=[];
    return StatefulBuilder(builder:(context,setLocal)=>_wrap('Guía por presupuesto','Indica cuánto quieres gastar y el uso principal. Mostraremos hasta tres opciones.',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Tu presupuesto en pesos mexicanos',prefixText:'\$')),
      const SizedBox(height:12),Wrap(spacing:8,children:[3000,5000,8000,12000,20000].map((v)=>ActionChip(label:Text(money(v)),onPressed:()=>setLocal(()=>amount.text='$v'))).toList()),
      const SizedBox(height:12),_categoryPicker(cat,(v)=>setLocal(()=>cat=v)),
      const SizedBox(height:12),DropdownButtonFormField<String>(value:use,decoration:const InputDecoration(labelText:'Uso principal'),items:const [DropdownMenuItem(value:'escuela',child:Text('Escuela y trabajo')),DropdownMenuItem(value:'gaming',child:Text('Gaming')),DropdownMenuItem(value:'fotos',child:Text('Fotos y redes'))],onChanged:(v)=>setLocal(()=>use=v??use)),
      const SizedBox(height:14),ElevatedButton.icon(onPressed:(){final p=int.tryParse(amount.text.replaceAll(',',''))??0;if(p<=0){_msg('Escribe un presupuesto válido.');return;}final pool=devices.where((d)=>(cat=='todos'||d.category==cat)&&d.price<=p).toList()..sort((a,b)=>((b.uses[use]??0) as num).compareTo((a.uses[use]??0) as num));setLocal(()=>result=pool.take(3).toList());},icon:const Icon(Icons.search),label:const Text('Encontrar dispositivos')),
      if(result.isNotEmpty)...[const SizedBox(height:18),Text('Tus mejores opciones',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),...result.map((d)=>_deviceCard(d))],
      if(result.isEmpty)const Padding(padding:EdgeInsets.only(top:16),child:Text('Los precios son orientativos en MXN. Verifica disponibilidad, condición y garantía antes de comprar.',style:TextStyle(color:Colors.grey)))
    ])));
  }
  Widget _scanner()=>_wrap('Escáner de compra','Usa una fotografía o la cámara para acompañar una revisión guiada del equipo.',const ScannerPanel());
  Widget _workshops()=>_wrap('Talleres','Consejos para elegir un servicio técnico y proteger tu dispositivo.',Column(children:[
    _workshop('Antes de entregar tu equipo','Solicita un diagnóstico y presupuesto por escrito. Pregunta qué piezas serán reemplazadas y cuánto tardará la reparación.'),
    _workshop('Garantía de reparación','Pide que indiquen por escrito el plazo de garantía, las piezas instaladas y las condiciones del servicio.'),
    _workshop('Protege tu información','Haz una copia de seguridad, cierra sesiones sensibles cuando sea posible y no compartas tus contraseñas.'),
    _workshop('Preguntas recomendadas','¿Cuál es el costo total? ¿La pieza es original o compatible? ¿Qué garantía ofrecen? ¿Me entregan la pieza sustituida?')
  ]));
  Widget _workshop(String t,String s)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:7),Text(s)])));
}

class ScannerPanel extends StatefulWidget { const ScannerPanel({super.key}); @override State<ScannerPanel> createState()=>_ScannerPanelState(); }
class _ScannerPanelState extends State<ScannerPanel>{
  final picker=ImagePicker(); XFile? photo; bool running=false,done=false; int progress=0;
  final steps=['Revisa que la pantalla no tenga manchas, líneas o zonas sin respuesta.','Comprueba cámaras, micrófono, bocinas y botones.','Verifica batería, carga y temperatura.','Confirma que Wi-Fi, Bluetooth y red móvil funcionen.','Revisa IMEI, número de serie y que no tenga reporte.','Comprueba que no tenga cuentas ajenas ni bloqueos.'];
  Future<void> choose(ImageSource source) async {try{final p=await picker.pickImage(source:source,imageQuality:80);if(p!=null)setState(()=>photo=p);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No fue posible abrir la cámara o galería.')));}}
  Future<void> scan() async {setState(() { running=true; done=false; progress=0; });for(int i=1;i<=steps.length;i++){await Future.delayed(const Duration(milliseconds:550));if(!mounted)return;setState(()=>progress=i);}setState(() { running=false; done=true; });}
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
      Container(height:190,width:double.infinity,decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(16)),child:photo==null?const Icon(Icons.phone_android,size:90,color:aqua):ClipRRect(borderRadius:BorderRadius.circular(16),child:Image.file(File(photo!.path),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.image,size:70)))),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[
        OutlinedButton.icon(onPressed:()=>choose(ImageSource.camera),icon:const Icon(Icons.camera_alt),label:const Text('Tomar foto')),
        OutlinedButton.icon(onPressed:()=>choose(ImageSource.gallery),icon:const Icon(Icons.photo_library),label:const Text('Elegir foto'))
      ])
    ]))),
    const SizedBox(height:12),ElevatedButton.icon(onPressed:running?null:scan,icon:const Icon(Icons.document_scanner),label:Text(running?'Revisando…':'Iniciar revisión guiada')),
    const SizedBox(height:12),LinearProgressIndicator(value:progress/steps.length,minHeight:7,borderRadius:BorderRadius.circular(10)),const SizedBox(height:8),Text('$progress de ${steps.length} pasos completados'),
    ...steps.asMap().entries.map((e)=>Card(child:ListTile(leading:Icon(e.key<progress?Icons.check_circle:Icons.radio_button_unchecked,color:e.key<progress?Colors.green:Colors.grey),title:Text('Paso ${e.key+1}'),subtitle:Text(e.value)))),
    if(done)const Card(color:Color(0x1A00C2D3),child:Padding(padding:EdgeInsets.all(14),child:Text('Revisión simulada: TecnoCheck no analiza la imagen ni detecta fallas automáticamente. Realiza cada comprobación directamente en el dispositivo. Si detectas una falla importante, no efectúes el pago.'))),
    const Text('Aviso: esta herramienta es una lista de comprobación orientativa, no un diagnóstico técnico.',style:TextStyle(color:Colors.grey,fontSize:12))
  ]);
}
