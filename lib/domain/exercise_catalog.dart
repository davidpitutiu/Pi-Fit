import 'models.dart';

/// Original, Romanian-language coaching notes. Equipment names and muscle
/// groups are deliberately consistent to support filtering throughout the app.
const List<Exercise> exerciseCatalog = [
  // Piept: împins orizontal, înclinat și adducție.
  Exercise(
    id: 'bench_press',
    name: 'Împins la bancă cu bara',
    muscle: 'Piept',
    equipment: 'Bară',
    secondaryMuscles: 'Triceps, umeri anteriori',
    description: 'Împins orizontal pentru forța și masa pectoralilor.',
    steps: [
      'Așază-te cu ochii sub bară, tălpile stabile și omoplații apropiați.',
      'Desprinde bara și coboar-o controlat spre partea inferioară a pieptului.',
      'Împinge bara în sus, păstrând șezutul pe bancă.',
    ],
    tips: [
      'Folosește opritoare sau un partener la seriile grele.',
      'Păstrează încheieturile deasupra antebrațelor și evită ricoșeul de pe piept.',
    ],
  ),
  Exercise(
    id: 'incline_dumbbell_press',
    name: 'Împins înclinat cu gantere',
    muscle: 'Piept',
    equipment: 'Gantere',
    secondaryMuscles: 'Umeri anteriori, triceps',
    description:
        'Varianta înclinată pune accent pe porțiunea superioară a pieptului.',
    steps: [
      'Reglează banca la aproximativ 20–35 de grade.',
      'Pornește cu ganterele lângă piept și antebrațele aproape verticale.',
      'Împinge în sus și coboară lent în aceeași traiectorie.',
    ],
    tips: [
      'O înclinare foarte mare mută efortul spre umeri.',
      'Păstrează o amplitudine confortabilă, fără să forțezi întinderea.',
    ],
  ),
  Exercise(
    id: 'dumbbell_press',
    name: 'Împins orizontal cu gantere',
    muscle: 'Piept',
    equipment: 'Gantere',
    secondaryMuscles: 'Triceps, umeri anteriori',
    description: 'Împins cu mișcare independentă a brațelor, util pentru control și simetrie.',
    steps: [
      'Așază ganterele pe coapse înainte de a te întinde pe bancă.',
      'Coboară coatele ușor sub linia trunchiului, dacă este confortabil.',
      'Împinge ganterele deasupra pieptului, fără să le lovești între ele.',
    ],
    tips: [
      'Ține tălpile pe podea și umerii stabili.',
      'Încheie seria înainte să pierzi controlul ganterelor.',
    ],
  ),
  Exercise(
    id: 'chest_fly',
    name: 'Fluturări cu gantere',
    muscle: 'Piept',
    equipment: 'Gantere',
    secondaryMuscles: 'Umeri anteriori',
    description:
        'Mișcare de adducție pentru pectorali, cu o încărcare moderată.',
    steps: [
      'Întinde-te pe bancă și ține ganterele deasupra pieptului.',
      'Deschide brațele cu coatele ușor îndoite și unghiul lor aproape fix.',
      'Adu ganterele înapoi deasupra pieptului printr-un arc controlat.',
    ],
    tips: [
      'Nu coborî mai jos decât permite confortul umărului.',
      'Alege greutăți mai mici decât la împins.',
    ],
  ),
  Exercise(
    id: 'cable_fly',
    name: 'Fluturări la cabluri',
    muscle: 'Piept',
    equipment: 'Cablu',
    secondaryMuscles: 'Umeri anteriori',
    description: 'Adducție la cabluri cu tensiune pe întreaga mișcare.',
    steps: [
      'Reglează scripeții aproape de nivelul umerilor și fă un pas înainte.',
      'Ține trunchiul stabil, coatele ușor îndoite și brațele deschise.',
      'Apropie mâinile în fața pieptului, apoi revino controlat.',
    ],
    tips: [
      'Menține aceeași îndoire a coatelor pe parcurs.',
      'Nu transforma fluturarea într-un împins.',
    ],
  ),
  Exercise(
    id: 'push_up',
    name: 'Flotări',
    muscle: 'Piept',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Triceps, umeri, abdomen',
    description:
        'Împins cu greutatea corpului, adaptabil prin înălțimea sprijinului.',
    steps: [
      'Sprijină palmele puțin mai larg decât umerii și aliniază corpul.',
      'Coboară pieptul între palme, cu coatele orientate oblic spre spate.',
      'Împinge podeaua și revino cu abdomenul încordat.',
    ],
    tips: [
      'Ridică palmele pe o bancă pentru o variantă mai ușoară.',
      'Păstrează șoldurile în linie cu trunchiul.',
    ],
  ),
  Exercise(
    id: 'chest_press',
    name: 'Împins la aparat pentru piept',
    muscle: 'Piept',
    equipment: 'Aparat',
    secondaryMuscles: 'Triceps, umeri anteriori',
    description: 'Împins ghidat care reduce cerințele de stabilizare.',
    steps: [
      'Reglează șezutul astfel încât mânerele să fie la mijlocul pieptului.',
      'Lipește spatele de suport și așază tălpile ferm.',
      'Împinge mânerele înainte și revino lent fără să lași greutățile să cadă.',
    ],
    tips: [
      'Evită ridicarea umerilor spre urechi.',
      'Reglează poziția de pornire dacă simți întindere excesivă în umăr.',
    ],
  ),
  Exercise(
    id: 'dips',
    name: 'Dips la paralele',
    muscle: 'Piept',
    equipment: 'Paralele',
    secondaryMuscles: 'Triceps, umeri anteriori',
    description:
        'Împins vertical cu greutatea corpului și trunchiul ușor înclinat.',
    steps: [
      'Prinde barele și stabilizează corpul cu brațele întinse.',
      'Coboară lent, menținând antebrațele aproape verticale.',
      'Împinge în bare și revino fără să balansezi picioarele.',
    ],
    tips: [
      'Folosește aparatul asistat dacă nu poți controla coborârea.',
      'Oprește coborârea înainte de apariția disconfortului în umăr.',
    ],
  ),
  // Spate: tracțiune verticală, ramat și control scapular.
  Exercise(
    id: 'pull_up',
    name: 'Tracțiuni la bară',
    muscle: 'Spate',
    equipment: 'Bară de tracțiuni',
    secondaryMuscles: 'Biceps, antebrațe',
    description: 'Tracțiune verticală pentru dorsali, cu greutatea corpului.',
    steps: [
      'Prinde bara confortabil, puțin mai larg decât umerii.',
      'Trage coatele spre trunchi până când bărbia ajunge la nivelul barei.',
      'Coboară lent până la extensia confortabilă a brațelor.',
    ],
    tips: [
      'Începe cu tracțiuni asistate sau coborâri controlate.',
      'Evită elanul și extensia exagerată a gâtului.',
    ],
  ),
  Exercise(
    id: 'lat_pulldown',
    name: 'Tracțiuni la helcometru',
    muscle: 'Spate',
    equipment: 'Cablu',
    secondaryMuscles: 'Biceps, antebrațe',
    description: 'Tracțiune verticală la cablu, cu încărcare ușor de ajustat.',
    steps: [
      'Fixează coapsele sub suport și prinde bara cu palmele înainte.',
      'Trage bara spre partea superioară a pieptului, conducând cu coatele.',
      'Lasă brațele să se întindă lent, fără să ridici șezutul.',
    ],
    tips: [
      'Ține trunchiul ușor înclinat, fără balans.',
      'Trage în fața capului și păstrează gâtul neutru.',
    ],
  ),
  Exercise(
    id: 'barbell_row',
    name: 'Ramat cu bara',
    muscle: 'Spate',
    equipment: 'Bară',
    secondaryMuscles: 'Biceps, deltoizi posteriori, lombari',
    description: 'Ramat din aplecat pentru musculatura spatelui și controlul trunchiului.',
    steps: [
      'Îndoaie ușor genunchii și împinge șoldurile înapoi.',
      'Cu spatele stabil, trage bara spre abdomen.',
      'Coboară bara controlat fără să schimbi unghiul trunchiului.',
    ],
    tips: [
      'Alege greutatea care îți permite să eviți smuciturile.',
      'Dacă zona lombară limitează mișcarea, folosește ramatul cu pieptul sprijinit.',
    ],
  ),
  Exercise(
    id: 'seated_cable_row',
    name: 'Ramat la cablu din șezut',
    muscle: 'Spate',
    equipment: 'Cablu',
    secondaryMuscles: 'Biceps, deltoizi posteriori',
    description:
        'Tracțiune orizontală cu rezistență constantă și priză neutră.',
    steps: [
      'Sprijină tălpile și așază-te cu genunchii ușor îndoiți.',
      'Trage mânerul spre abdomen, ducând coatele înapoi.',
      'Revino lent și permite omoplaților să se deplaseze fără să rotunjești lombarul.',
    ],
    tips: [
      'Evită să te lași pe spate pentru a deplasa greutatea.',
      'Păstrează umerii departe de urechi.',
    ],
  ),
  Exercise(
    id: 'dumbbell_row',
    name: 'Ramat unilateral cu gantera',
    muscle: 'Spate',
    equipment: 'Gantere',
    secondaryMuscles: 'Biceps, deltoizi posteriori',
    description:
        'Ramat pe fiecare parte, cu sprijin pentru stabilitatea trunchiului.',
    steps: [
      'Sprijină o mână și un genunchi pe bancă sau folosește un sprijin stabil.',
      'Trage gantera spre șold, păstrând cotul aproape de corp.',
      'Coboară lent și repetă același număr pe cealaltă parte.',
    ],
    tips: [
      'Nu roti trunchiul pentru a ridica greutatea.',
      'Începe cu partea mai puțin puternică.',
    ],
  ),
  Exercise(
    id: 'face_pull',
    name: 'Face pull la cablu',
    muscle: 'Umeri',
    equipment: 'Cablu',
    secondaryMuscles: 'Trapez, rotatori externi',
    description:
        'Tracțiune spre față pentru deltoizii posteriori și control scapular.',
    steps: [
      'Montează o frânghie la nivelul feței și prinde capetele.',
      'Trage spre frunte, depărtând mâinile și ridicând coatele confortabil.',
      'Revino controlat, cu trunchiul nemișcat.',
    ],
    tips: [
      'Folosește greutăți mici pentru a păstra controlul.',
      'Nu împinge capul înainte pentru a întâlni frânghia.',
    ],
  ),
  Exercise(
    id: 'straight_arm_pulldown',
    name: 'Tracțiuni cu brațele întinse',
    muscle: 'Spate',
    equipment: 'Cablu',
    secondaryMuscles: 'Triceps, abdomen',
    description: 'Extensie a umărului la cablu, cu accent pe dorsali.',
    steps: [
      'Prinde bara de la un scripete înalt și înclină ușor trunchiul.',
      'Menține coatele puțin îndoite și trage bara spre coapse.',
      'Revino lent până când brațele se apropie de linia trunchiului.',
    ],
    tips: [
      'Păstrează unghiul coatelor aproape constant.',
      'Nu compensa prin arcuirea zonei lombare.',
    ],
  ),
  Exercise(
    id: 'chest_supported_row',
    name: 'Ramat cu pieptul sprijinit',
    muscle: 'Spate',
    equipment: 'Gantere',
    secondaryMuscles: 'Biceps, deltoizi posteriori',
    description: 'Ramat pe bancă înclinată, cu sprijin pentru trunchi.',
    steps: [
      'Așază pieptul pe o bancă înclinată și sprijină bine picioarele.',
      'Trage ganterele în lateralul trunchiului, fără să ridici pieptul.',
      'Coboară lent până la întinderea confortabilă a brațelor.',
    ],
    tips: [
      'Reglează banca astfel încât ganterele să nu atingă podeaua.',
      'Ține gâtul în prelungirea spatelui.',
    ],
  ),
  // Umeri: împins, abducție și deltoizi posteriori.
  Exercise(
    id: 'overhead_press',
    name: 'Împins deasupra capului cu bara',
    muscle: 'Umeri',
    equipment: 'Bară',
    secondaryMuscles: 'Triceps, abdomen',
    description: 'Împins vertical din picioare pentru umeri și stabilitate.',
    steps: [
      'Pornește cu bara în fața umerilor și coatele ușor înainte.',
      'Încordează abdomenul și împinge bara pe lângă față.',
      'Revino lent la umeri fără să arcuiești spatele.',
    ],
    tips: [
      'Strânge fesierii pentru a stabiliza bazinul.',
      'Folosește o variantă din șezut dacă nu poți controla trunchiul.',
    ],
  ),
  Exercise(
    id: 'dumbbell_shoulder_press',
    name: 'Împins pentru umeri cu gantere',
    muscle: 'Umeri',
    equipment: 'Gantere',
    secondaryMuscles: 'Triceps',
    description:
        'Împins vertical din șezut cu mișcare independentă a brațelor.',
    steps: [
      'Sprijină spatele pe o bancă aproape verticală.',
      'Ține ganterele lângă umeri cu antebrațele verticale.',
      'Împinge în sus și coboară controlat, menținând coastele stabile.',
    ],
    tips: [
      'Priza neutră poate fi mai confortabilă pentru unii umeri.',
      'Nu lăsa coatele să cadă mult în spatele trunchiului.',
    ],
  ),
  Exercise(
    id: 'lateral_raise',
    name: 'Ridicări laterale cu gantere',
    muscle: 'Umeri',
    equipment: 'Gantere',
    secondaryMuscles: 'Trapez',
    description: 'Abducție a brațelor cu accent pe partea laterală a umerilor.',
    steps: [
      'Stai drept cu ganterele lângă coapse și coatele ușor îndoite.',
      'Ridică brațele ușor înaintea liniei corpului până spre nivelul umerilor.',
      'Coboară lent fără să lași ganterele să cadă.',
    ],
    tips: [
      'Condu mișcarea cu coatele, fără să ridici umerii.',
      'Folosește o greutate care nu cere balans.',
    ],
  ),
  Exercise(
    id: 'front_raise',
    name: 'Ridicări frontale cu gantere',
    muscle: 'Umeri',
    equipment: 'Gantere',
    secondaryMuscles: 'Piept superior',
    description: 'Flexie a umărului pentru deltoidul anterior.',
    steps: [
      'Ține ganterele în fața coapselor, cu abdomenul stabil.',
      'Ridică brațele în față până aproximativ la nivelul umerilor.',
      'Coboară în ritm lent, păstrând coatele ușor îndoite.',
    ],
    tips: [
      'Poți alterna brațele pentru a controla mai bine mișcarea.',
      'Volumul de împins lucrează deja partea anterioară a umărului.',
    ],
  ),
  Exercise(
    id: 'reverse_fly',
    name: 'Fluturări inverse cu gantere',
    muscle: 'Umeri',
    equipment: 'Gantere',
    secondaryMuscles: 'Romboizi, trapez',
    description:
        'Deschidere a brațelor din aplecat pentru deltoizii posteriori.',
    steps: [
      'Înclină trunchiul din șolduri și menține spatele stabil.',
      'Deschide brațele în lateral cu coatele ușor îndoite.',
      'Revino lent sub linia pieptului.',
    ],
    tips: [
      'Folosește o bancă pentru sprijin dacă obosește zona lombară.',
      'Oprește mișcarea când brațele ajung în linie cu trunchiul.',
    ],
  ),
  Exercise(
    id: 'cable_lateral_raise',
    name: 'Ridicări laterale la cablu',
    muscle: 'Umeri',
    equipment: 'Cablu',
    secondaryMuscles: 'Trapez',
    description: 'Variantă unilaterală a ridicărilor laterale, cu rezistență la pornire.',
    steps: [
      'Stai lateral față de un scripete jos și prinde mânerul cu brațul exterior.',
      'Ridică brațul în lateral, ușor înaintea trunchiului.',
      'Coboară lent și schimbă partea după toate repetările.',
    ],
    tips: [
      'Nu înclina trunchiul pentru a ajuta ridicarea.',
      'Păstrează mișcarea într-un interval confortabil pentru umăr.',
    ],
  ),
  // Biceps: flexii cu priză supinată și neutră.
  Exercise(
    id: 'barbell_curl',
    name: 'Flexii pentru biceps cu bara',
    muscle: 'Biceps',
    equipment: 'Bară',
    secondaryMuscles: 'Antebrațe',
    description: 'Flexie bilaterală a cotului cu priză supinată.',
    steps: [
      'Prinde bara aproximativ la lățimea umerilor, cu palmele înainte.',
      'Ridică bara prin îndoirea coatelor, menținând brațele lângă trunchi.',
      'Coboară lent până aproape de întinderea completă.',
    ],
    tips: [
      'Evită impulsul din șolduri.',
      'Folosește o bară EZ dacă priza dreaptă produce disconfort.',
    ],
  ),
  Exercise(
    id: 'dumbbell_curl',
    name: 'Flexii cu gantere',
    muscle: 'Biceps',
    equipment: 'Gantere',
    secondaryMuscles: 'Antebrațe',
    description:
        'Flexii independente ale brațelor, cu rotație controlată a palmei.',
    steps: [
      'Stai drept cu ganterele lângă corp.',
      'Îndoaie coatele și rotește palmele în sus pe măsură ce ridici.',
      'Coboară lent, păstrând coatele aproape de trunchi.',
    ],
    tips: [
      'Păstrează încheieturile neutre.',
      'Repetările alternative pot facilita controlul fiecărui braț.',
    ],
  ),
  Exercise(
    id: 'hammer_curl',
    name: 'Flexii ciocan',
    muscle: 'Biceps',
    equipment: 'Gantere',
    secondaryMuscles: 'Brahial, brahioradial',
    description: 'Flexii cu priză neutră pentru brațe și antebrațe.',
    steps: [
      'Ține ganterele cu palmele orientate una spre cealaltă.',
      'Îndoaie coatele fără să rotești palmele.',
      'Coboară lent și menține umerii relaxați.',
    ],
    tips: [
      'Nu duce coatele înainte pentru a încheia repetarea.',
      'Alege o greutate care permite o coborâre controlată.',
    ],
  ),
  Exercise(
    id: 'preacher_curl',
    name: 'Flexii la banca Scott',
    muscle: 'Biceps',
    equipment: 'Bară EZ',
    secondaryMuscles: 'Antebrațe',
    description: 'Flexii cu brațele sprijinite pentru a limita elanul.',
    steps: [
      'Reglează banca astfel încât brațele să se sprijine confortabil pe pernă.',
      'Ridică bara prin flexia coatelor, fără să desprinzi brațele.',
      'Coboară lent, oprindu-te înainte de o extensie forțată.',
    ],
    tips: [
      'Începe conservator; rezistența poate fi mare în partea de jos.',
      'Nu relaxa brusc brațele la finalul coborârii.',
    ],
  ),
  Exercise(
    id: 'cable_curl',
    name: 'Flexii pentru biceps la cablu',
    muscle: 'Biceps',
    equipment: 'Cablu',
    secondaryMuscles: 'Antebrațe',
    description: 'Flexii la scripete jos cu tensiune continuă.',
    steps: [
      'Prinde bara de la scripetele de jos și fă un pas înapoi.',
      'Ridică bara spre umeri, ținând coatele fixe lângă corp.',
      'Revino lent fără să lași plăcile să se lovească.',
    ],
    tips: [
      'Stabilizează trunchiul înaintea fiecărei repetări.',
      'Nu îndoi încheieturile pentru a ridica bara mai sus.',
    ],
  ),
  Exercise(
    id: 'incline_curl',
    name: 'Flexii cu gantere pe bancă înclinată',
    muscle: 'Biceps',
    equipment: 'Gantere',
    secondaryMuscles: 'Antebrațe',
    description:
        'Flexii cu brațele în spatele trunchiului și spatele sprijinit.',
    steps: [
      'Așază-te pe o bancă înclinată și lasă brațele să atârne natural.',
      'Îndoaie coatele cu palmele orientate înainte.',
      'Coboară controlat fără să împingi brațele și mai mult în spate.',
    ],
    tips: [
      'Folosește o înclinare și o amplitudine confortabile pentru umeri.',
      'Păstrează capul și spatele sprijinite.',
    ],
  ),
  // Triceps: extensii și împins cu priză apropiată.
  Exercise(
    id: 'triceps_pushdown',
    name: 'Extensii pentru triceps la cablu',
    muscle: 'Triceps',
    equipment: 'Cablu',
    secondaryMuscles: 'Antebrațe',
    description: 'Extensie a cotului la scripete înalt cu frânghie sau bară.',
    steps: [
      'Prinde mânerul și așază coatele lângă trunchi.',
      'Întinde brațele spre coapse fără să miști umerii.',
      'Revino lent până când antebrațele urcă într-o poziție confortabilă.',
    ],
    tips: [
      'Nu folosi greutatea corpului pentru a apăsa mânerul.',
      'Ține încheieturile în linie cu antebrațele.',
    ],
  ),
  Exercise(
    id: 'overhead_triceps_extension',
    name: 'Extensii triceps deasupra capului',
    muscle: 'Triceps',
    equipment: 'Cablu',
    secondaryMuscles: 'Umeri',
    description: 'Extensie la cablu cu brațele deasupra capului.',
    steps: [
      'Prinde frânghia și întoarce-te cu spatele la scripete.',
      'Ține brațele ridicate și îndoaie coatele controlat.',
      'Întinde coatele fără să arcuiești spatele.',
    ],
    tips: [
      'Alege o poziție a brațelor care nu provoacă disconfort.',
      'Menține coastele coborâte și abdomenul încordat.',
    ],
  ),
  Exercise(
    id: 'skull_crusher',
    name: 'Extensii pentru triceps din culcat',
    muscle: 'Triceps',
    equipment: 'Bară EZ',
    secondaryMuscles: 'Umeri',
    description: 'Extensii ale cotului din culcat pe bancă, cu bară EZ.',
    steps: [
      'Întinde-te pe bancă și ține bara deasupra pieptului.',
      'Îndoaie coatele și coboară bara controlat spre zona de deasupra frunții.',
      'Întinde brațele păstrând brațele superioare aproape fixe.',
    ],
    tips: [
      'Folosește greutăți moderate și o priză sigură.',
      'Un partener te poate ajuta să preiei și să lași bara.',
    ],
  ),
  Exercise(
    id: 'close_grip_press',
    name: 'Împins cu priză apropiată',
    muscle: 'Triceps',
    equipment: 'Bară',
    secondaryMuscles: 'Piept, umeri anteriori',
    description:
        'Variantă de împins la bancă cu accent mai mare pe extensia cotului.',
    steps: [
      'Prinde bara aproximativ la lățimea umerilor.',
      'Coboară spre partea inferioară a pieptului cu coatele aproape de corp.',
      'Împinge înapoi, păstrând încheieturile deasupra antebrațelor.',
    ],
    tips: [
      'O priză extrem de îngustă nu este necesară.',
      'Folosește opritoare sau un partener la seriile solicitante.',
    ],
  ),
  // Picioare: genuflexiuni, extensia genunchiului și variante unilaterale.
  Exercise(
    id: 'squat',
    name: 'Genuflexiuni cu bara',
    muscle: 'Cvadricepși',
    equipment: 'Bară',
    secondaryMuscles: 'Fesieri, adductori, abdomen',
    description: 'Mișcare compusă pentru picioare, cu bara sprijinită pe partea superioară a spatelui.',
    steps: [
      'Fixează bara pe spate și așază tălpile într-o poziție confortabilă.',
      'Inspiră, stabilizează trunchiul și coboară prin îndoirea genunchilor și șoldurilor.',
      'Împinge podeaua și ridică-te cu genunchii în direcția degetelor.',
    ],
    tips: [
      'Reglează opritoarele cadrului înaintea seriei.',
      'Adâncimea trebuie să îți permită să păstrezi controlul și echilibrul.',
    ],
  ),
  Exercise(
    id: 'front_squat',
    name: 'Genuflexiuni frontale',
    muscle: 'Cvadricepși',
    equipment: 'Bară',
    secondaryMuscles: 'Fesieri, abdomen, spate superior',
    description: 'Genuflexiune cu bara pe partea din față a umerilor.',
    steps: [
      'Sprijină bara pe umeri și ridică coatele pentru a crea un suport stabil.',
      'Coboară cu trunchiul cât mai vertical și tălpile ancorate.',
      'Ridică-te menținând coatele sus și abdomenul stabil.',
    ],
    tips: [
      'Începe ușor pentru a învăța poziția de susținere.',
      'Folosește opritoare și evită să susții bara doar în mâini.',
    ],
  ),
  Exercise(
    id: 'goblet_squat',
    name: 'Genuflexiuni goblet',
    muscle: 'Cvadricepși',
    equipment: 'Gantere',
    secondaryMuscles: 'Fesieri, abdomen',
    description: 'Genuflexiune cu o ganteră ținută în fața pieptului.',
    steps: [
      'Ține gantera aproape de piept și așază tălpile stabil.',
      'Coboară controlat între șolduri, cu genunchii urmărind degetele.',
      'Împinge podeaua și revino în picioare fără să te lași pe vârfuri.',
    ],
    tips: [
      'Este o variantă bună pentru a exersa genuflexiunea.',
      'Păstrează gantera aproape de corp pe toată durata seriei.',
    ],
  ),
  Exercise(
    id: 'leg_press',
    name: 'Presă pentru picioare',
    muscle: 'Cvadricepși',
    equipment: 'Aparat',
    secondaryMuscles: 'Fesieri, adductori',
    description: 'Împins ghidat cu picioarele, cu spatele sprijinit.',
    steps: [
      'Așază tălpile pe platformă și verifică mecanismul de siguranță.',
      'Coboară platforma cât timp bazinul rămâne sprijinit pe scaun.',
      'Împinge controlat fără să blochezi agresiv genunchii.',
    ],
    tips: [
      'Nu coborî atât de mult încât lombarul să se desprindă.',
      'Verifică blocarea platformei înainte să ieși din aparat.',
    ],
  ),
  Exercise(
    id: 'leg_extension',
    name: 'Extensii pentru cvadricepși',
    muscle: 'Cvadricepși',
    equipment: 'Aparat',
    secondaryMuscles: '',
    description: 'Extensie izolată a genunchiului la aparat.',
    steps: [
      'Aliniază genunchiul cu axul aparatului și perna deasupra gleznelor.',
      'Întinde genunchii controlat fără să ridici șoldurile.',
      'Coboară lent până la poziția de pornire.',
    ],
    tips: [
      'Reglează spătarul pentru sprijin complet.',
      'Alege o amplitudine care nu provoacă durere la genunchi.',
    ],
  ),
  Exercise(
    id: 'lunge',
    name: 'Fandări cu gantere',
    muscle: 'Cvadricepși',
    equipment: 'Gantere',
    secondaryMuscles: 'Fesieri, ischiogambieri',
    description: 'Mișcare unilaterală pentru picioare și echilibru.',
    steps: [
      'Ține ganterele lângă corp și fă un pas suficient de lung.',
      'Coboară ambele genunchiuri, păstrând talpa din față ancorată.',
      'Împinge prin piciorul din față și revino, apoi schimbă partea.',
    ],
    tips: [
      'Păstrează suficient spațiu lateral între picioare pentru echilibru.',
      'Fandarea înapoi este o alternativă ușor de controlat.',
    ],
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    name: 'Genuflexiuni bulgărești',
    muscle: 'Cvadricepși',
    equipment: 'Gantere',
    secondaryMuscles: 'Fesieri, adductori',
    description:
        'Genuflexiune unilaterală cu piciorul din spate sprijinit pe bancă.',
    steps: [
      'Sprijină piciorul din spate pe o bancă joasă și găsește o poziție stabilă.',
      'Coboară controlat, lăsând piciorul din față să preia cea mai mare parte a efortului.',
      'Împinge prin talpa din față și revino fără să sari.',
    ],
    tips: [
      'Exersează întâi fără greutăți și folosește un sprijin pentru echilibru.',
      'Alege o înălțime a băncii confortabilă pentru șold.',
    ],
  ),
  Exercise(
    id: 'step_up',
    name: 'Urcări pe bancă',
    muscle: 'Cvadricepși',
    equipment: 'Gantere',
    secondaryMuscles: 'Fesieri, gambe',
    description: 'Urcare unilaterală pe o platformă stabilă.',
    steps: [
      'Așază toată talpa unui picior pe o platformă solidă.',
      'Împinge prin piciorul de pe platformă și ridică corpul.',
      'Coboară lent pe același picior și repetă apoi pe cealaltă parte.',
    ],
    tips: [
      'Alege o platformă care permite urcarea fără elan.',
      'Limitează împingerea din piciorul rămas jos.',
    ],
  ),
  // Lanț posterior: extensia șoldului și flexia genunchiului.
  Exercise(
    id: 'deadlift',
    name: 'Îndreptări cu bara',
    muscle: 'Ischiogambieri',
    equipment: 'Bară',
    secondaryMuscles: 'Fesieri, spate, antebrațe',
    description: 'Ridicare de la sol prin extensia coordonată a genunchilor și șoldurilor.',
    steps: [
      'Așază bara aproape de tibii și prinde-o în afara picioarelor.',
      'Stabilizează spatele, îndepărtează jocul din bară și împinge podeaua.',
      'Ridică-te cu bara aproape de corp, apoi coboară prin șolduri și genunchi.',
    ],
    tips: [
      'Resetează poziția între repetări dacă pierzi controlul.',
      'La final stai drept, fără să te înclini înapoi.',
    ],
  ),
  Exercise(
    id: 'romanian_deadlift',
    name: 'Îndreptări românești',
    muscle: 'Ischiogambieri',
    equipment: 'Bară',
    secondaryMuscles: 'Fesieri, lombari',
    description:
        'Mișcare dominantă de șold pentru partea posterioară a coapselor.',
    steps: [
      'Pornește în picioare cu bara lângă coapse și genunchii ușor flexați.',
      'Împinge șoldurile înapoi și coboară bara aproape de picioare.',
      'Revino prin extensia șoldurilor când simți întindere controlată în coapse.',
    ],
    tips: [
      'Bara nu trebuie să atingă solul la fiecare repetare.',
      'Oprește coborârea înainte să rotunjești spatele.',
    ],
  ),
  Exercise(
    id: 'leg_curl',
    name: 'Flexii femurali din culcat',
    muscle: 'Ischiogambieri',
    equipment: 'Aparat',
    secondaryMuscles: 'Gambe',
    description: 'Flexie a genunchilor din culcat pentru musculatura posterioară a coapsei.',
    steps: [
      'Aliniază genunchii cu axul aparatului și suportul lângă glezne.',
      'Îndoaie genunchii pentru a apropia călcâiele de șezut.',
      'Coboară lent, menținând bazinul pe suport.',
    ],
    tips: [
      'Nu arcui spatele pentru a ridica greutatea.',
      'Controlează mai ales ultima parte a coborârii.',
    ],
  ),
  Exercise(
    id: 'seated_leg_curl',
    name: 'Flexii femurali din șezut',
    muscle: 'Ischiogambieri',
    equipment: 'Aparat',
    secondaryMuscles: 'Gambe',
    description: 'Flexie a genunchilor cu coapsele și trunchiul sprijinite.',
    steps: [
      'Reglează spătarul și perna de deasupra coapselor.',
      'Îndoaie genunchii și trage suportul în jos, fără să ridici șezutul.',
      'Revino controlat până la extensia confortabilă.',
    ],
    tips: [
      'Aliniază articulația genunchiului cu pivotul aparatului.',
      'Evită să lași plăcile să se lovească între repetări.',
    ],
  ),
  Exercise(
    id: 'hip_thrust',
    name: 'Hip thrust cu bara',
    muscle: 'Fesieri',
    equipment: 'Bară',
    secondaryMuscles: 'Ischiogambieri, abdomen',
    description:
        'Extensie a șoldului cu partea superioară a spatelui pe bancă.',
    steps: [
      'Sprijină omoplații pe o bancă fixă și protejează bazinul cu o pernă.',
      'Așază tălpile stabil și ridică bazinul prin împingerea în podea.',
      'Oprește când trunchiul și coapsele se aliniază, apoi coboară lent.',
    ],
    tips: [
      'Menține coastele coborâte pentru a limita extensia lombară.',
      'Verifică stabilitatea băncii înainte de încărcare.',
    ],
  ),
  Exercise(
    id: 'glute_bridge',
    name: 'Podul fesier',
    muscle: 'Fesieri',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Ischiogambieri, abdomen',
    description: 'Extensie de șold de la sol, potrivită pentru învățarea controlului bazinului.',
    steps: [
      'Întinde-te pe spate cu genunchii îndoiți și tălpile pe podea.',
      'Încordează abdomenul și ridică bazinul până la alinierea cu trunchiul.',
      'Coboară lent fără să pierzi controlul lombar.',
    ],
    tips: [
      'Împinge prin întreaga talpă.',
      'Nu încerca să ridici bazinul peste poziția neutră a șoldurilor.',
    ],
  ),
  Exercise(
    id: 'cable_kickback',
    name: 'Extensii de șold la cablu',
    muscle: 'Fesieri',
    equipment: 'Cablu',
    secondaryMuscles: 'Ischiogambieri',
    description: 'Extensie unilaterală de șold cu manșetă la gleznă.',
    steps: [
      'Prinde manșeta de un scripete jos și ține-te de un sprijin stabil.',
      'Du piciorul înapoi prin mișcarea șoldului, cu genunchiul ușor îndoit.',
      'Revino lent fără să rotești bazinul.',
    ],
    tips: [
      'O amplitudine mică și controlată este suficientă.',
      'Păstrează lombarul stabil și nu folosi elan.',
    ],
  ),
  Exercise(
    id: 'hip_abduction',
    name: 'Abducții la aparat',
    muscle: 'Fesieri',
    equipment: 'Aparat',
    secondaryMuscles: 'Abductori ai șoldului',
    description: 'Depărtarea coapselor din șezut pentru musculatura laterală a șoldului.',
    steps: [
      'Reglează poziția de pornire și sprijină spatele pe scaun.',
      'Depărtează genunchii într-un interval controlat.',
      'Revino lent fără să lași greutățile să se lovească.',
    ],
    tips: [
      'Nu schimba poziția trunchiului pentru a mișca mai multă greutate.',
      'Păstrează pelvisul stabil pe șezut.',
    ],
  ),
  // Gambe: extensia gleznei cu genunchii drepți sau îndoiți.
  Exercise(
    id: 'standing_calf_raise',
    name: 'Ridicări pe vârfuri din picioare',
    muscle: 'Gambe',
    equipment: 'Aparat',
    secondaryMuscles: '',
    description: 'Flexie plantară din picioare pentru musculatura gambelor.',
    steps: [
      'Sprijină partea din față a tălpilor pe platformă și stabilizează corpul.',
      'Ridică-te pe vârfuri fără să îndoi activ genunchii.',
      'Coboară călcâiele lent până la o întindere confortabilă.',
    ],
    tips: [
      'Evită să ricoșezi în partea de jos.',
      'Folosește un sprijin solid dacă faci varianta cu gantere.',
    ],
  ),
  Exercise(
    id: 'seated_calf_raise',
    name: 'Ridicări pe vârfuri din șezut',
    muscle: 'Gambe',
    equipment: 'Aparat',
    secondaryMuscles: '',
    description: 'Flexie plantară cu genunchii îndoiți, cu accent pe solear.',
    steps: [
      'Așază coapsele sub suport și partea din față a tălpilor pe platformă.',
      'Ridică călcâiele cât poți controla, fără să desprinzi șezutul.',
      'Coboară lent într-o amplitudine confortabilă.',
    ],
    tips: [
      'Menține o scurtă pauză sus și jos pentru control.',
      'Reglează suportul astfel încât să nu apese direct pe rotule.',
    ],
  ),
  // Core: stabilizare, flexie și control antirotațional.
  Exercise(
    id: 'plank',
    name: 'Planșă pe antebrațe',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Umeri, fesieri',
    description: 'Menținere izometrică pentru stabilitatea trunchiului; durata se urmărește în secunde.',
    steps: [
      'Sprijină antebrațele sub umeri și întinde picioarele.',
      'Încordează abdomenul și fesierii pentru a păstra corpul aliniat.',
      'Respiră regulat și încheie menținerea când pierzi poziția.',
    ],
    tips: [
      'Înregistrează durata în secunde în câmpul de repetări.',
      'O variantă pe genunchi sau cu sprijin ridicat reduce dificultatea.',
    ],
  ),
  Exercise(
    id: 'side_plank',
    name: 'Planșă laterală',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Fesieri, umeri',
    description: 'Stabilizare laterală pentru trunchi; durata se urmărește în secunde pe parte.',
    steps: [
      'Așază cotul sub umăr și aliniază corpul pe o parte.',
      'Ridică bazinul de pe podea și păstrează șoldurile suprapuse.',
      'Respiră controlat, apoi repetă pe cealaltă parte.',
    ],
    tips: [
      'Înregistrează secundele pentru fiecare parte.',
      'Sprijină genunchii pe podea pentru o variantă mai ușoară.',
    ],
  ),
  Exercise(
    id: 'crunch',
    name: 'Crunch abdominal',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: '',
    description: 'Flexie controlată a trunchiului cu amplitudine redusă.',
    steps: [
      'Întinde-te pe spate cu genunchii îndoiți și mâinile pe piept.',
      'Expiră și ridică omoplații de pe sol prin contracția abdomenului.',
      'Coboară lent fără să tragi de cap.',
    ],
    tips: [
      'Privește ușor în sus și păstrează gâtul relaxat.',
      'O mișcare scurtă și controlată este suficientă.',
    ],
  ),
  Exercise(
    id: 'cable_crunch',
    name: 'Crunch la cablu',
    muscle: 'Abdomen',
    equipment: 'Cablu',
    secondaryMuscles: '',
    description:
        'Flexie abdominală cu rezistență ajustabilă la scripete înalt.',
    steps: [
      'Îngenunchează la cablu și ține frânghia lângă cap.',
      'Apropie coastele de bazin prin flexia trunchiului.',
      'Revino lent, păstrând șoldurile aproape nemișcate.',
    ],
    tips: [
      'Brațele țin frânghia și nu trag greutatea.',
      'Nu transforma mișcarea într-o aplecare din șolduri.',
    ],
  ),
  Exercise(
    id: 'hanging_knee_raise',
    name: 'Ridicări de genunchi la bară',
    muscle: 'Abdomen',
    equipment: 'Bară de tracțiuni',
    secondaryMuscles: 'Flexori ai șoldului, antebrațe',
    description: 'Ridicări de genunchi cu control al bazinului și fără balans.',
    steps: [
      'Prinde bara sau folosește stația cu sprijin pentru antebrațe.',
      'Ridică genunchii și rotește ușor bazinul spre coaste.',
      'Coboară lent până la oprirea balansului.',
    ],
    tips: [
      'Începe cu genunchii îndoiți și amplitudine redusă.',
      'Oprește seria dacă priza sau umerii nu mai sunt stabili.',
    ],
  ),
  Exercise(
    id: 'dead_bug',
    name: 'Dead bug',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Flexori ai șoldului',
    description: 'Control al trunchiului în timpul mișcării alternative a brațelor și picioarelor.',
    steps: [
      'Întinde-te pe spate cu brațele sus și șoldurile și genunchii la aproximativ 90 de grade.',
      'Întinde lent un picior și brațul opus, păstrând lombarul stabil.',
      'Revino și alternează părțile cu respirație controlată.',
    ],
    tips: [
      'Redu amplitudinea dacă spatele se arcuiește.',
      'Numără o repetare pentru fiecare parte efectuată.',
    ],
  ),
  Exercise(
    id: 'russian_twist',
    name: 'Rotații rusești',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Oblici, flexori ai șoldului',
    description: 'Rotație controlată din șezut, cu sprijin al tălpilor pentru stabilitate.',
    steps: [
      'Așază-te cu genunchii îndoiți, tălpile pe sol și trunchiul ușor înclinat.',
      'Rotește lent partea superioară a trunchiului într-o parte.',
      'Revino prin centru și rotește spre partea opusă.',
    ],
    tips: [
      'Menține mișcarea mică și evită rotirea forțată a lombarului.',
      'Numără fiecare parte ca o repetare.',
    ],
  ),
  Exercise(
    id: 'bird_dog',
    name: 'Bird dog',
    muscle: 'Abdomen',
    equipment: 'Greutatea corpului',
    secondaryMuscles: 'Fesieri, extensori spinali',
    description: 'Stabilizare în patru puncte cu extensia membrelor opuse.',
    steps: [
      'Așază palmele sub umeri și genunchii sub șolduri.',
      'Întinde un braț și piciorul opus fără să rotești bazinul.',
      'Revino controlat și schimbă partea.',
    ],
    tips: [
      'Imaginează-ți că echilibrezi un pahar pe bazin.',
      'Ridică membrele doar până la linia trunchiului.',
    ],
  ),
  // Condiționare: mișcări ciclice și balistice.
  Exercise(
    id: 'treadmill',
    name: 'Mers sau alergare pe bandă',
    muscle: 'Cardio',
    equipment: 'Bandă de alergare',
    secondaryMuscles: 'Cvadricepși, gambe, fesieri',
    description: 'Condiționare cardiovasculară prin mers sau alergare cu viteză ajustabilă.',
    steps: [
      'Atașează clema de siguranță și pornește la viteză mică.',
      'Crește treptat ritmul sau înclinația la o intensitate sustenabilă.',
      'Încheie reducând treptat viteza pentru câteva minute.',
    ],
    tips: [
      'Înregistrează durata în minute în câmpul de repetări.',
      'Evită să te sprijini continuu în mânere.',
    ],
  ),
  Exercise(
    id: 'stationary_bike',
    name: 'Bicicletă staționară',
    muscle: 'Cardio',
    equipment: 'Bicicletă',
    secondaryMuscles: 'Cvadricepși, fesieri, gambe',
    description:
        'Efort cardiovascular cu impact redus și rezistență reglabilă.',
    steps: [
      'Reglează șaua astfel încât genunchiul să rămână ușor îndoit jos.',
      'Pedalează într-un ritm lin și crește rezistența treptat.',
      'Redu intensitatea înainte să închei sesiunea.',
    ],
    tips: [
      'Înregistrează durata în minute în câmpul de repetări.',
      'Păstrează umerii relaxați și genunchii orientați înainte.',
    ],
  ),
  Exercise(
    id: 'rower',
    name: 'Vâslit la ergometru',
    muscle: 'Cardio',
    equipment: 'Ergometru',
    secondaryMuscles: 'Picioare, spate, brațe',
    description: 'Condiționare a întregului corp printr-o secvență coordonată de împins și tras.',
    steps: [
      'Prinde mânerul, fixează tălpile și începe cu brațele întinse.',
      'Împinge cu picioarele, deschide șoldurile și apoi trage mânerul spre coaste.',
      'Revino cu brațele, apoi trunchiul și la final genunchii.',
    ],
    tips: [
      'Înregistrează durata în minute în câmpul de repetări.',
      'Învață secvența cu rezistență moderată înainte de intervale intense.',
    ],
  ),
  Exercise(
    id: 'jump_rope',
    name: 'Sărituri cu coarda',
    muscle: 'Cardio',
    equipment: 'Coardă',
    secondaryMuscles: 'Gambe, umeri, abdomen',
    description: 'Sărituri ritmice pentru coordonare și condiționare.',
    steps: [
      'Ține coatele aproape de corp și rotește coarda din încheieturi.',
      'Sari suficient cât să treacă coarda, aterizând ușor.',
      'Menține un ritm confortabil și ia pauze înainte să pierzi coordonarea.',
    ],
    tips: [
      'Înregistrează numărul de sărituri în câmpul de repetări.',
      'Alege o suprafață stabilă care nu este excesiv de dură.',
    ],
  ),
  Exercise(
    id: 'elliptical',
    name: 'Bicicletă eliptică',
    muscle: 'Cardio',
    equipment: 'Eliptică',
    secondaryMuscles: 'Cvadricepși, fesieri, brațe',
    description: 'Efort ciclic cu sprijin permanent al picioarelor pe pedale.',
    steps: [
      'Urcă folosind mânerele fixe și pornește cu rezistență mică.',
      'Deplasează pedalele fluent și coordonează brațele cu picioarele.',
      'Redu ritmul înainte de oprire și coboară când pedalele sunt stabile.',
    ],
    tips: [
      'Înregistrează durata în minute în câmpul de repetări.',
      'Păstrează trunchiul drept și evită apăsarea excesivă în mânere.',
    ],
  ),
  Exercise(
    id: 'kettlebell_swing',
    name: 'Swing cu kettlebell',
    muscle: 'Fesieri',
    equipment: 'Kettlebell',
    secondaryMuscles: 'Ischiogambieri, abdomen, antebrațe',
    description: 'Extensie explozivă a șoldului cu kettlebell; presupune stăpânirea mișcării de hip hinge.',
    steps: [
      'Așază kettlebellul în față și preia-l prin împingerea șoldurilor înapoi.',
      'Balansul pornește dintre picioare, apoi întinde șoldurile pentru a propulsa greutatea.',
      'Lasă kettlebellul să revină și absoarbe mișcarea din șolduri.',
    ],
    tips: [
      'Brațele ghidează greutatea; nu o ridică activ.',
      'Învață tehnica cu un antrenor înainte de intervale rapide sau încărcături mari.',
    ],
  ),
];

/// Set and repetition targets are starting points; loading is deliberately zero
/// until the athlete chooses an appropriate working weight.
const List<Routine> routineTemplates = [
  Routine(
    id: 'push',
    name: 'Push day',
    subtitle: 'Piept · Umeri · Triceps',
    estimatedMinutes: 55,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'bench_press', sets: 4, reps: 8),
      RoutineExercise(exerciseId: 'incline_dumbbell_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_shoulder_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lateral_raise', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'triceps_pushdown', sets: 3, reps: 12),
    ],
  ),
  Routine(
    id: 'pull',
    name: 'Pull day',
    subtitle: 'Spate · Deltoizi posteriori · Biceps',
    estimatedMinutes: 50,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 4, reps: 10),
      RoutineExercise(exerciseId: 'seated_cable_row', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_row', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'face_pull', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'dumbbell_curl', sets: 3, reps: 12),
    ],
  ),
  Routine(
    id: 'legs',
    name: 'Leg day',
    subtitle: 'Cvadricepși · Femurali · Gambe',
    estimatedMinutes: 60,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'squat', sets: 4, reps: 8),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'leg_press', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'leg_curl', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'standing_calf_raise', sets: 4, reps: 15),
    ],
  ),
  Routine(
    id: 'full_body',
    name: 'Full body',
    subtitle: 'Un antrenament. Tot corpul.',
    estimatedMinutes: 45,
    category: 'Începător',
    exercises: [
      RoutineExercise(exerciseId: 'goblet_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'chest_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 2, reps: 10),
      RoutineExercise(exerciseId: 'dead_bug', sets: 2, reps: 12),
    ],
  ),
  Routine(
    id: 'upper',
    name: 'Upper body',
    subtitle: 'Forță și echilibru pentru partea superioară',
    estimatedMinutes: 55,
    category: 'Upper / Lower',
    exercises: [
      RoutineExercise(exerciseId: 'dumbbell_press', sets: 3, reps: 8),
      RoutineExercise(exerciseId: 'chest_supported_row', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_shoulder_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'hammer_curl', sets: 2, reps: 12),
      RoutineExercise(exerciseId: 'triceps_pushdown', sets: 2, reps: 12),
    ],
  ),
  Routine(
    id: 'lower',
    name: 'Lower body',
    subtitle: 'Picioare puternice, progres constant',
    estimatedMinutes: 50,
    category: 'Upper / Lower',
    exercises: [
      RoutineExercise(exerciseId: 'leg_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'bulgarian_split_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'seated_leg_curl', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'seated_calf_raise', sets: 3, reps: 15),
    ],
  ),
  Routine(
    id: 'glutes',
    name: 'Glute focus',
    subtitle: 'Fesieri · Lanț posterior · Stabilitate',
    estimatedMinutes: 45,
    category: 'Hipertrofie',
    exercises: [
      RoutineExercise(exerciseId: 'hip_thrust', sets: 4, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'bulgarian_split_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'cable_kickback', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'hip_abduction', sets: 3, reps: 15),
    ],
  ),
  Routine(
    id: 'home',
    name: 'Acasă, fără scuze',
    subtitle: 'Fără aparate. Doar tu și progresul tău.',
    estimatedMinutes: 25,
    category: 'Acasă',
    exercises: [
      RoutineExercise(exerciseId: 'push_up', sets: 3, reps: 8),
      RoutineExercise(exerciseId: 'glute_bridge', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'crunch', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'bird_dog', sets: 2, reps: 12),
      RoutineExercise(exerciseId: 'dead_bug', sets: 2, reps: 12),
    ],
  ),
];

/// A safe lookup for screens and imported histories that may reference an
/// exercise removed from a future catalogue version.
Exercise? exerciseById(String id) {
  for (final exercise in exerciseCatalog) {
    if (exercise.id == id) return exercise;
  }
  return null;
}
