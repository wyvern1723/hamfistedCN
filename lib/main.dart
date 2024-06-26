import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';

const GREEN = Color(0xff73a946);
const RED = Color(0xff992413);
const PRIMARY = Color(0xff1d5479);
const double MAX_WIDTH = 400;

const double INTRO_BOTTOM = 220;

const List DECAY = [
  1000 * 60 * 60 * 24 * 21,
  1000 * 60 * 60 * 24 * 14,
  1000 * 60 * 60 * 24 * 7,
  1000 * 60 * 60 * 24 * 3
];

class ListWithDecay {
  ListWithDecay(this.decay);
  int decay = 0;
  List<String> entries = [];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalData.instance.launchGlobalData;
  runApp(ChangeNotifierProvider<GlobalData>.value(
      value: GlobalData.instance, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // final textTheme = Theme.of(context).textTheme;
    return MaterialApp(
      title: 'hamfistedCN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PRIMARY,
        ),
        //textTheme: GoogleFonts.alegreyaSansTextTheme(textTheme),
      ),
      home: const Overview(),
      routes: {
        '/overview': (context) => const Overview(),
        '/quiz': (context) => const Quiz(),
        '/about': (context) => const About(),
      },
    );
  }
}

class Overview extends StatefulWidget {
  const Overview({super.key});

  @override
  State<Overview> createState() => _OverviewState();
}

class _OverviewState extends State<Overview> with TickerProviderStateMixin {
  Future<void> clearProgress() async {
    await GlobalData.box.clear();
    setState(() {});
  }

  List<Widget> getChapterCards({String hid = '', bool demo = false}) {
    List<Widget> cards = [];
    int now = DateTime.now().millisecondsSinceEpoch;
    Random r = Random(0);
    for (var subhid in (GlobalData.questions!['children'][hid] ?? [])) {
      List<int> countForDuration = [0, 0, 0, 0, 0];
      if (demo) {
        countForDuration = [10, 13, 9, 2, 28];
        countForDuration.shuffle(r);
      } else {
        for (String qid
            in (GlobalData.questions!['questions_for_hid'][subhid] ?? [])) {
          int ts = GlobalData.box.get("t/$qid") ?? 0;
          int diff = now - ts;
          int slot = 4;
          if (diff < DECAY[0]) slot = 3;
          if (diff < DECAY[1]) slot = 2;
          if (diff < DECAY[2]) slot = 1;
          if (diff < DECAY[3]) slot = 0;
          countForDuration[slot] += 1;
        }
      }
      String label = GlobalData.questions!['headings'][subhid] ?? subhid;
      cards.add(
        InkWell(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(PRIMARY, Colors.white, 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Text(
                              "${(GlobalData.questions!['questions_for_hid'][subhid] ?? []).length}",
                              style: GoogleFonts.alegreyaSans(
                                  fontSize: 14, color: Colors.black87)),
                        )),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int k = 0; k <= 4; k++)
                        if (countForDuration[k] > 0)
                          Flexible(
                            flex: countForDuration[k],
                            child: LinearProgressIndicator(
                              backgroundColor: const Color(0x20000000),
                              color: Color.lerp(PRIMARY, Colors.white, k / 5),
                              value: 1.0,
                            ),
                          ),
                    ]),
              ),
            ),
          ),
          onTap: () {
            if (demo) return;
            if (GlobalData.questions!['children'][subhid] != null) {
              Navigator.of(context)
                  .pushNamed('/overview', arguments: subhid)
                  .then((value) {
                setState(() {});
              });
            } else {
              Navigator.of(context)
                  .pushNamed('/quiz', arguments: subhid)
                  .then((value) {
                setState(() {});
              });
            }
          },
        ),
      );
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    if (!GlobalData.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    //delete
    String hid = '';
    if (ModalRoute.of(context) != null) {
      hid = (ModalRoute.of(context)!.settings.arguments ?? '').toString();
    }

    var cards = getChapterCards(hid: hid);

    Future<void> showMyDialog(BuildContext context) async {
      return showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('删除学习进度'),
            content: const SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('您确定要删除所有学习进度吗？'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('取消'),
                onPressed: () async {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('删除'),
                onPressed: () async {
                  await clearProgress();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Color.lerp(PRIMARY, Colors.white, 0.9),
      appBar: AppBar(
        backgroundColor: PRIMARY,
        foregroundColor: Colors.white,
        actions: hid.isEmpty
            ? [
                PopupMenuButton(onSelected: (value) async {
                  if (value == 'clear_progress') {
                    showMyDialog(context);
                  } else if (value == 'about') {
                    Navigator.of(context).pushNamed('/about');
                  }
                }, itemBuilder: (itemBuilder) {
                  return <PopupMenuEntry>[
                    const PopupMenuItem<String>(
                      value: "clear_progress",
                      child: ListTile(
                        title: Text("删除学习进度"),
                        visualDensity: VisualDensity.compact,
                        leading: Icon(Icons.delete),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: "about",
                      child: ListTile(
                        title: Text("关于 App"),
                        visualDensity: VisualDensity.compact,
                        leading: Icon(Icons.info),
                      ),
                    ),
                  ];
                })
              ]
            : null,
        title:
            Text((GlobalData.questions!['headings'][hid] ?? '业余电台操作证书考试题库练习')),
      ),
      body: ListView(
        children: cards,
      ),
      bottomNavigationBar: hid == ''
          ? null
          : Container(
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(color: Color(0x80000000), blurRadius: 5)
              ]),
              child: TextButton(
                child: Text(
                    "练习所有 ${(GlobalData.questions!['questions_for_hid'][hid] ?? []).length} 道题",
                    style: GoogleFonts.alegreyaSans()),
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed('/quiz', arguments: hid)
                      .then((value) {
                    setState(() {});
                  });
                },
              )),
    );
  }
}

class Quiz extends StatefulWidget {
  const Quiz({super.key});

  @override
  State<Quiz> createState() => _QuizState();
}

class _QuizState extends State<Quiz> with TickerProviderStateMixin {
  String? hid;
  String? qid;
  bool unsure = false;
  List<Color> answerColor = [];
  List<int> answerIndex = [];
  bool guessedWrong = false;
  bool foundCorrect = false;
  bool animationPhase1 = false;
  bool animationPhase2 = false;
  bool animationPhase3 = false;
  bool solvedAll = false;
  Timer? _timer;
  double overallProgress = 0.0;
  double? overallProgressFirst;

  late final AnimationController _animationController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  late final AnimationController _animationController2 = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  late final AnimationController _animationController3 = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animationController2.dispose();
    _animationController3.dispose();
    super.dispose();
  }

  void pickTask() {
    guessedWrong = false;
    foundCorrect = false;
    unsure = false;
    // get all questions for this heading
    List<String> candidates = [];
    for (String x in GlobalData.questions!['questions_for_hid'][hid]) {
      candidates.add(x);
    }
    int now = DateTime.now().millisecondsSinceEpoch;
    List<ListWithDecay> candidatesSorted = [
      ListWithDecay(0),
      ListWithDecay(1),
      ListWithDecay(2),
      ListWithDecay(3),
      ListWithDecay(4)
    ];
    for (String qid in candidates) {
      int ts = GlobalData.box.get("t/$qid") ?? 0;
      int diff = now - ts;
      int slot = 4;
      if (diff < DECAY[0]) slot = 3;
      if (diff < DECAY[1]) slot = 2;
      if (diff < DECAY[2]) slot = 1;
      if (diff < DECAY[3]) slot = 0;
      candidatesSorted[slot].entries.add(qid);
    }
    overallProgress = (candidatesSorted[0].entries.length +
                candidatesSorted[1].entries.length +
                candidatesSorted[2].entries.length +
                candidatesSorted[3].entries.length)
            .toDouble() /
        candidates.length;
    overallProgressFirst ??= overallProgress;

    candidatesSorted.removeWhere((element) => element.entries.isEmpty);
    solvedAll = (candidatesSorted.last.decay == 0);
    candidates = candidatesSorted.last.entries;
    candidates.shuffle();
    setState(() {
      qid = candidates[0];
      answerColor = [
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
        Colors.transparent
      ];
      answerIndex = [0, 1, 2, 3];
      answerIndex.shuffle();
    });
  }

  void launchAnimation({bool quick = false}) {
    _animationController.reset();
    _animationController2.reset();
    _animationController3.reset();
    if (quick) {
      animationPhase1 = true;
      animationPhase2 = true;
      _animationController.animateTo(1.0, curve: Curves.easeInOutCubic);
      _animationController2
          .animateTo(1.0, curve: Curves.easeInOutCubic)
          .then((value) {
        animationPhase3 = true;
        setState(() {
          pickTask();
        });
        _animationController3
            .animateTo(1.0, curve: Curves.easeInOutCubic)
            .then((value) {
          setState(() {
            animationPhase1 = false;
            animationPhase2 = false;
            animationPhase3 = false;
            _animationController.reset();
            _animationController2.reset();
            _animationController3.reset();
          });
        });
      });
    } else {
      animationPhase1 = true;
      _animationController
          .animateTo(1.0, curve: Curves.easeInOutCubic)
          .then((value) {
        animationPhase1 = false;
        animationPhase2 = true;
        _animationController2
            .animateTo(1.0, curve: Curves.easeInOutCubic)
            .then((value) {
          animationPhase3 = true;
          setState(() {
            pickTask();
          });
          _animationController3
              .animateTo(1.0, curve: Curves.easeInOutCubic)
              .then((value) {
            setState(() {
              animationPhase1 = false;
              animationPhase2 = false;
              animationPhase3 = false;
              _animationController.reset();
              _animationController2.reset();
              _animationController3.reset();
            });
          });
        });
      });
    }
  }

  void tapAnswer(int i) {
    if (unsure && foundCorrect && answerColor[i] != Colors.transparent) {
      launchAnimation();
      return;
    }
    if (i == 0) {
      // answer is correct
      foundCorrect = true;
      answerColor[i] = GREEN;
      if (!guessedWrong) {
        if (!unsure) {
          GlobalData.instance
              .markQuestionSolved(qid!, DateTime.now().millisecondsSinceEpoch);
        }
      }
      if (!unsure) {
        launchAnimation();
      }
    } else {
      // answer is wrong
      answerColor[i] = RED;
      guessedWrong = true;
      unsure = true;
      GlobalData.instance.unmarkQuestionSolved(qid!);
      solvedAll = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hid == null) {
      // get current heading
      if (ModalRoute.of(context) != null) {
        hid = (ModalRoute.of(context)!.settings.arguments ?? '').toString();
      }
    }
    if (qid == null) {
      pickTask();
    }
    // qid = '2024_AF420';

    List<Widget> cards = [];
    String qidDisplay = qid ?? '';
    if (qidDisplay.endsWith('E') || qidDisplay.endsWith('A')) {
      qidDisplay = qidDisplay.substring(0, qidDisplay.length - 1);
    }
    qidDisplay = qidDisplay.replaceFirst('2024_', '');

    cards.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(
            begin: overallProgressFirst,
            end: overallProgress,
          ),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0x20000000),
            color: Color.lerp(PRIMARY, Colors.black, 0.5),
          ),
        ),
      ),
    );

    cards.add(LayoutBuilder(builder: (context, constraints) {
      double cwidth = min(constraints.maxWidth, MAX_WIDTH);
      List<Widget> challengeParts = [];

      if (GlobalData.questions!['questions'][qid]['challenge'] != null) {
        challengeParts.add(Container(
          constraints: BoxConstraints(maxWidth: cwidth),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Html(
              data:
                  "<b>$qidDisplay</b>&nbsp;&nbsp;&nbsp;&nbsp;${GlobalData.questions!['questions'][qid]['challenge']}",
              style: {
                'body': Style(
                  margin: Margins.zero,
                  fontSize: FontSize(16),
                ),
                "b": Style(fontFamily: GoogleFonts.alegreyaSans().fontFamily)
              },
            ),
          ),
        ));
      }

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        child: Column(children: challengeParts),
      );
    }));

    cards.add(const Divider());

    for (int ti = 0; ti < 4; ti++) {
      int i = answerIndex[ti];
      cards.add(
        Padding(
          padding:
              ti == 3 ? const EdgeInsets.only(bottom: 105) : EdgeInsets.zero,
          child: AnimatedBuilder(
              animation: _animationController3,
              builder: (context, child) {
                return AnimatedBuilder(
                    animation: _animationController2,
                    builder: (context, child) {
                      return AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return LayoutBuilder(
                                builder: (context, constraints) {
                              double cwidth =
                                  min(constraints.maxWidth, MAX_WIDTH);
                              Offset offset = Offset.zero;
                              if (animationPhase1) {
                                if (i != 0) {
                                  offset = Offset(
                                      -1 * _animationController.value, 0);
                                }
                              }
                              if (animationPhase2) {
                                if (i != 0 && !animationPhase1) {
                                  offset = const Offset(-1, 0);
                                } else {
                                  offset =
                                      Offset(-_animationController2.value, 0);
                                }
                              }
                              if (animationPhase3) {
                                offset = Offset(
                                    1.0 - _animationController3.value, 0);
                              }
                              return Transform.translate(
                                offset: offset * constraints.maxWidth,
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  surfaceTintColor: Colors.transparent,
                                  child: InkWell(
                                    onTapCancel: () => _timer?.cancel(),
                                    onTapDown: (_) => {
                                      _timer = Timer(
                                          const Duration(milliseconds: 1500),
                                          () {
                                        setState(() {
                                          unsure = true;
                                          tapAnswer(i);
                                        });
                                      })
                                    },
                                    onTap: () {
                                      _timer?.cancel();
                                      setState(() {
                                        tapAnswer(i);
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: answerColor[i],
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: max(
                                                  0,
                                                  (constraints.maxWidth -
                                                              cwidth) /
                                                          2 -
                                                      15)),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Center(
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                        answerColor[i] ==
                                                                Colors
                                                                    .transparent
                                                            ? Color.lerp(
                                                                PRIMARY,
                                                                Colors.white,
                                                                0.8)
                                                            : answerColor[i],
                                                    radius: cwidth * 0.045,
                                                    child:
                                                        answerColor[i] == GREEN
                                                            ? Icon(
                                                                Icons.check,
                                                                color: Colors
                                                                    .white,
                                                                size: cwidth *
                                                                    0.05,
                                                              )
                                                            : answerColor[i] ==
                                                                    RED
                                                                ? Icon(
                                                                    Icons.clear,
                                                                    color: Colors
                                                                        .white,
                                                                    size:
                                                                        cwidth *
                                                                            0.05,
                                                                  )
                                                                : Text(
                                                                    String.fromCharCode(
                                                                        65 +
                                                                            ti),
                                                                    style: GoogleFonts.alegreyaSans(
                                                                        fontSize:
                                                                            cwidth *
                                                                                0.04,
                                                                        color: answerColor[i] == Colors.transparent
                                                                            ? Colors
                                                                                .black87
                                                                            : Colors
                                                                                .white,
                                                                        fontWeight: answerColor[i] ==
                                                                                Colors.transparent
                                                                            ? FontWeight.normal
                                                                            : FontWeight.bold),
                                                                  ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width:
                                                    cwidth * (1.0 - 0.045) - 70,
                                                child: (Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 13.0),
                                                  child: Html(
                                                    data: GlobalData
                                                        .questions!['questions']
                                                            [qid]['answers'][i]
                                                        .toString()
                                                        .replaceAll('*', ' ⋅ '),
                                                    style: {
                                                      'body': Style(
                                                        margin: Margins.zero,
                                                      ),
                                                    },
                                                  ),
                                                )),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          });
                    });
              }),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color.lerp(PRIMARY, Colors.white, 0.9),
      appBar: AppBar(
        backgroundColor: PRIMARY,
        foregroundColor: Colors.white,
        title: Text(
            (GlobalData.questions!['headings'][hid] ?? 'Amateurfunkprüfung')),
      ),
      body: Stack(
        children: [
          Container(
            child: ListView(
              children: cards,
            ),
          ),
          BottomMenu(
            qid: qid!,
            feelingUnsureWidget: Transform.scale(
              scale: 1,
              child: Switch(
                value: unsure,
                activeColor: Colors.red[900],
                onChanged: (value) {
                  if (!unsure) {
                    setState(() => unsure = value);
                  }
                },
              ),
            ),
            onFeelingUnsure: () {
              unsure = true;
            },
            onHelp: GlobalData.questions!['questions'][qid]['hint'] == null
                ? null
                : () {
                    String? url =
                        GlobalData.questions!['questions'][qid]['hint'];
                    developer.log("$url");
                    if (url != null) {
                      setState(() => unsure = true);
                      launchUrl(Uri.parse(url));
                    }
                  },
            onSkip: () {
              launchAnimation(quick: true);
            },
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Opacity(
              opacity: solvedAll ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100, right: 10),
                child: ElevatedButton.icon(
                  style: ButtonStyle(
                    surfaceTintColor:
                        MaterialStateProperty.all(Colors.transparent),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    elevation: MaterialStateProperty.all(4),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10000)),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text(
                    "已回答所有问题！",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  String version = "n/a";
  void getVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
    });
  }

  @override
  void initState() {
    super.initState();
    getVersionInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(PRIMARY, Colors.white, 0.9),
      appBar: AppBar(
        title: const Text("关于 App"),
        backgroundColor: PRIMARY,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Html(
          data: "<h2>Hamfisted</h2>"
              "<p>App zur Vorbereitung auf die Amateurfunkprüfung</p>"
              "<p>Die Fragen von 2007 stammen aus der AFUTrainer-App von <a href='http://oliver-saal.de/software/afutrainer/download.php'>Oliver Saal</a>. Die Fragen von 2024 stammen von der Bundesnetzagentur (3. Auflage, März 2024). Grafiken stammen von <a href='https://freepik.com'>freepik.com</a>. Implementiert von Michael Specht.</p>"
              "<p><b>Version:</b> ${version}</p>"
              "<p><b>Quelltext:</b> <a href='https://github.com/specht/hamfisted'>https://github.com/specht/hamfisted</a></p>"
              "<p><b>Kontakt:</b> <a href='mailto:specht@gymnasiumsteglitz.de'>specht@gymnasiumsteglitz.de</a></p>"
              "<h3>机翻：</h3>"
              "<p>一个用于准备业余无线电考试的应用程序</p>"
              "<p>2007 年的问题来自 <a href='http://oliver-saal.de/software/afutrainer/download.php'>Oliver Saal</a> 的 AFUTrainer-App。 2024 年的题目来自 Bundesnetzagentur (3. Auflage, März 2024)。 图片来自 <a href='https://freepik.com'>freepik.com</a>。 由 Michael Specht 实现。</p>"
              "<p><b>版本：</b> ${version}</p>"
              "<p><b>资料来源：</b> <a href='https://github.com/specht/hamfisted'>https://github.com/specht/hamfisted</a></p>"
              "<p><b>联络：</b> <a href='mailto:specht@gymnasiumsteglitz.de'>specht@gymnasiumsteglitz.de</a></p>"
              "<hr />"
              "<h2>HamfistedCN</h2>"
              "<p>基于 <a href='https://github.com/specht'>Michael Specht</a> 的 <a href='https://github.com/specht/hamfisted'>Hamfisted</a> 修改</p>"
              "<p>替换中国 A、B、C 类业余无线电台操作技术能力验证题库</p>"
              "<p><b>版本：</b> ${version}</p>"
              "<p><b>资料来源：</b> <a href='https://github.com/specht/hamfisted'>中国无线电协会业余无线电分会(CRAC)</a></p>"
              "<p><b>项目主页：</b> <a href='https://github.com/wyvern1723/hamfistedCN'>https://github.com/wyvern1723/hamfistedCN</a></p>",
          style: {
            'body': Style(fontFamily: GoogleFonts.alegreyaSans().fontFamily)
          },
          onLinkTap: (url, attributes, element) {
            launchUrl(Uri.parse(url!));
          },
        ),
      ),
    );
  }
}

class BottomMenu extends StatefulWidget {
  final Function? onFeelingUnsure;
  final Widget feelingUnsureWidget;
  final Function? onHelp;
  final Function? onSkip;
  final String qid;

  const BottomMenu(
      {super.key,
      required this.qid,
      required this.feelingUnsureWidget,
      this.onFeelingUnsure,
      this.onSkip,
      this.onHelp});

  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 5)],
              color: Colors.white,
            ),
            child: Material(
              child: LayoutBuilder(builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth / 3,
                      child: InkWell(
                        onTap: widget.onFeelingUnsure == null
                            ? null
                            : () {
                                widget.onFeelingUnsure!();
                              },
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 8, left: 8, right: 8, bottom: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 45,
                                child: widget.feelingUnsureWidget,
                              ),
                              const Text(
                                "存疑",
                                textAlign: TextAlign.center,
                                style: TextStyle(height: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth / 3,
                      child: InkWell(
                        onTap: widget.onHelp == null
                            ? null
                            : () {
                                widget.onHelp!();
                              },
                        child: Opacity(
                          opacity: GlobalData.questions!['questions']
                                      [widget.qid]['hint'] ==
                                  null
                              ? 0.5
                              : 1.0,
                          child: const Padding(
                            padding: EdgeInsets.only(
                                top: 8, left: 8, right: 8, bottom: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    height: 45,
                                    child: Icon(Icons.help_outline)),
                                Text(
                                  "帮助",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(height: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth / 3,
                      child: InkWell(
                        onTap: widget.onSkip == null
                            ? null
                            : () {
                                widget.onSkip!();
                              },
                        child: const Padding(
                          padding: EdgeInsets.only(
                              top: 8, left: 8, right: 8, bottom: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  height: 45,
                                  child: Icon(Icons.skip_next_outlined)),
                              Text(
                                "跳过",
                                textAlign: TextAlign.center,
                                style: TextStyle(height: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class MyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path
      ..addOval(Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2), radius: 55))
      ..close();

    return Path.combine(
        PathOperation.difference,
        Path()
          ..addRRect(
              RRect.fromLTRBR(0, 0, size.width, size.height, Radius.zero)),
        path);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
