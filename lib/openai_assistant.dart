import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;

class OpenAIAssistant {
  String assistantId;
  String openAiApiKey;

  OpenAIAssistant({
    required this.assistantId, 
    required this.openAiApiKey,
  });

  Future<String> getResponse(String html) async {
    ProcessResult results = await Process.run(
        'python',
        [
          'lib/open_ai_assistant.py',
          '--name',
          '"username_input"',
          '--description',
          '"Login username input form field"',
          '--html',
          '"$html"'
        ],
      );
      String result = results.stdout.toString();
      return result;
  }
}

enum SelectorType {
  css,
  xpath;

  // From string
  static SelectorType fromString(String type) {
    switch (type) {
      case 'css': return SelectorType.css;
      case 'xpath': return SelectorType.xpath;
      default:
        throw Exception('Invalid selector type');
    }
  }
}

class Selector {
  SelectorType type;
  String value;

  Selector({
    required this.type,
    required this.value,
  });

  // From map
  Selector.fromMap(Map<String, dynamic> map)
      : type = SelectorType.fromString(map['type']),
        value = map['value'];
}

class PossibleSelectors {
  String name;
  String description;
  String html;

  PossibleSelectors({
    required this.name,
    required this.description,
    required this.html,
  });

  List<Selector> selectors = [];

  void parseSelectors(String response) {
    String res = response
      .replaceAll('\n', '')
      .replaceAll(' ', '');
    RegExp possibleSelectorRegex = RegExp(
      r'{"type":(.+?),"selector":(.+?)}',
      multiLine: true,
      caseSensitive: false,
      dotAll: true,
    );
    RegExp typeRegex = RegExp(
      r'"type":"(.+?)"',
      multiLine: true,
      caseSensitive: false,
      dotAll: true,
    );
    RegExp selectorRegex = RegExp(
      r'"selector":"(.+?)"',
      multiLine: true,
      caseSensitive: false,
      dotAll: true,
    );
    List<String> possibleSelectors =
      possibleSelectorRegex.allMatches(res).map((match) {
        return match.group(0)!;
    }).toList();
    print(possibleSelectors.toString());
    print('Possible selectors: $possibleSelectors');
    if (possibleSelectors.isEmpty) {
      print('No selectors found');
    }
    for (String possibleSelector in possibleSelectors) {
      try {
        print('\n\ntrying to parse selector: $possibleSelector\n\n');
        Selector selector = Selector.fromMap({
          'type': typeRegex.firstMatch(possibleSelector)!.group(1)!,
          'value': selectorRegex.firstMatch(possibleSelector)!.group(1)!,
        });
        // If selector is not already in the list, add it
        if (!selectors.contains(selector)) {
          selectors.add(selector);
        }
      } catch (e) {
        print('Error parsing selector: $e');
        continue;
      }
    }
  }
}

class PuppeteerWrapper {
  late pup.Browser browser;
  late pup.Page page;
  bool blocked = false;
  String htmlSnippet = '';

  late Function clickCallback;

  PuppeteerWrapper();

  Future<String?> pageClickListenerFunction(
    pup.ConsoleMessage msg,
  ) async {
    if (blocked) return null;
    if (msg.text == null) return null;
    if (msg.text!.contains('!clicked_element!')) {
      // Get only the HTML of the clicked element
      String clickedElement = msg.text!.split('!clicked_element!')[1];
      htmlSnippet = clickedElement;
      clickCallback(htmlSnippet);
    }
    return null;
  }

  Future<void> init() async {
    browser = await pup.puppeteer.launch(
      headless: false,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
      executablePath: '/usr/bin/google-chrome'
    );
    page = (await browser.pages).first;
  }

  Future<void> navigate(String url) async {
    await page.goto(url);
    await addClickEvent();
    page.onLoad.listen((_) async {
      await addClickEvent();
    });
    page.onConsole.listen(pageClickListenerFunction);
  }

  Future<void> close() async {
    await browser.close();
  }

  String get bgColor => blocked
      ? 'rgba(0, 0, 0, 0.3)'
      : 'rgba(255, 0, 0, 0.3)';



  Future<void> addClickEvent() async {
    await page.evaluate('''
      var previousElement;

      document.addEventListener('click', function(event) {
        if (previousElement) {
          previousElement.style.backgroundColor = '';
        }

        event.target.style.backgroundColor = '$bgColor';

        previousElement = event.target;

        console.log('!clicked_element!', event.target.outerHTML);
      });
    ''');
  }

  Future<void> waitForSelector(String selector) async {
    await page.waitForSelector(selector);
  }

  Future<void> click(String selector) async {
    await page.click(selector);
  }
}

class SelectorExtractorWidget extends StatefulWidget {
  late PuppeteerWrapper puppeteerWrapper;
  PossibleSelectors possibleSelectors = PossibleSelectors(
    name: '', description: '', html: '',
  );

  SelectorExtractorWidget({super.key});

  @override
  _SelectorExtractorWidgetState createState() => _SelectorExtractorWidgetState();
}

class _SelectorExtractorWidgetState extends State<SelectorExtractorWidget> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController htmlController;

  String _state = 'loading';

  Future<void> _init() async {
    // Instantiate PuppeteerWrapper
    widget.puppeteerWrapper = PuppeteerWrapper();
    await widget.puppeteerWrapper.init();
    widget.puppeteerWrapper.clickCallback = (String html) {
      setState(() {
        htmlController.text = html;
      });
    };
    await widget.puppeteerWrapper.navigate(
      'https://pub.dev/packages/window_manager/versions',
    );
  }

  void _goBackToFirstPage() {
    setState(() {
      _state = 'loaded';
    });
  }

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.possibleSelectors.name);
    htmlController = TextEditingController(text: widget.possibleSelectors.html);
    descriptionController = TextEditingController(
      text: widget.possibleSelectors.description,
    );

    // Instantiate PuppeteerWrapper
    _init().then((value) => setState(() {
      _state = 'loaded';
    }));
  }

  Widget _firstScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 5),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 5),
          TextField(
            controller: htmlController,
            decoration: InputDecoration(
              labelText: 'HTML',
              border: OutlineInputBorder(),
            ),
            maxLines: 14,
            readOnly: true,
          ),
          Spacer(),
          ElevatedButton(
            onPressed: () {
              widget.possibleSelectors.name = nameController.text;
              widget.possibleSelectors.description = descriptionController.text;
              widget.possibleSelectors.html = htmlController.text;
              widget.possibleSelectors.parseSelectors(htmlController.text);
              setState(() {
                _state = 'loading';
              });
              AiAssistantWrapper.getResult(
                name: widget.possibleSelectors.name, 
                description: widget.possibleSelectors.description, 
                html: widget.possibleSelectors.html,
              ).then((value) => 
                widget.possibleSelectors.parseSelectors(value)
              ).then((value) => 
                setState(() {
                  _state = 'result';
                })
              );
            },
            child: Text('Call AI Agent'),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // PossibleSelectors ListView
          Container(
            height: 490,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: SingleChildScrollView(
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.possibleSelectors.selectors.length,
                itemBuilder: (context, index) {
                  Selector selector = widget.possibleSelectors.selectors[index];
                  return ListTile(
                    title: Text(selector.value),
                    subtitle: Text(selector.type.toString()),
                  );
                },
              ),
            ),
          ),
          Spacer(),
          ElevatedButton(
            onPressed: _goBackToFirstPage,
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_state) {
      case 'loading':
        child = const CircularProgressIndicator();
        break;
      case 'loaded':
        child = _firstScreen();
        break;
      case 'result':
        child = _resultScreen();
        break;
      default:
        child = const Center(
          child: Text('Unknow app state')
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selector Extractor'),
      ),
      body: Center(
        child: child,
      )
    );
  }
}


class AiAssistantWrapper {
  static Future<String> getResult({
    required String name,
    required String description,
    required String html,
  }) async {
    ProcessResult results = await Process.run(
      'python', [
        'lib/open_ai_assistant.py',
          '--name', '"$name"',
          '--description', '"$description"',
          '--html', '"$html"'
      ],
    );
    print(results.stdout.toString());
    // Parse the response from the python script
    // and display it in the console
    return results.stdout.toString();
  }
}