import 'dart:io';

import 'package:puppeteer/puppeteer.dart';

void main() async {
  bool blocked = false;

  var browser = await puppeteer.launch(
      headless: false, args: ['--no-sandbox', '--disable-setuid-sandbox'],
      executablePath: '/usr/bin/google-chrome'
  );
  var page = await browser.newPage();

  await page.goto('http://192.168.1.1/',
      wait: Until.networkIdle);

  // // Type into search box.
  // await page.type('.devsite-search-field', 'Headless Chrome');
  // // Wait for suggest overlay to appear and click "show all results".
  // var allResultsSelector = '.devsite-suggest-all-results';
  // await page.waitForSelector(allResultsSelector);
  // await page.click(allResultsSelector);
  // // Wait for the results page to load and display the results.
  // const resultsSelector = '.gsc-results .gsc-thumbnail-inside a.gs-title';
  // await page.waitForSelector(resultsSelector);

  // Extract the results from the page.
  // var links = await page.evaluate<List<dynamic>>(r'''resultsSelector => {
  //   const anchors = Array.from(document.querySelectorAll(resultsSelector));
  //   return anchors.map(anchor => {
  //     const title = anchor.textContent.split('|')[0].trim();
  //     return `${title} - ${anchor.href}`;
  //   });
  // }''', args: [resultsSelector]);

  // For every user click at the web page, colours the element with
  // a red translucent overlay.
  String jsSnippet = '''
    var previousElement;

    document.addEventListener('click', function(event) {
        // Reset the background color of the previously clicked element
        if (previousElement) {
            previousElement.style.backgroundColor = '';
        }

        // Change the background color of the clicked element to translucent red
        event.target.style.backgroundColor = 'rgba(255, 0, 0, 0.3)';

        // Update the previously clicked element
        previousElement = event.target;

        console.log('!clicked_element!', event.target.outerHTML);
    });
  ''';
  String blockedJsSnippet = '''
    document.addEventListener('click', function(event) {
        if (previousElement) {
            previousElement.style.backgroundColor = 'rgba(0, 0, 0, 0.3)';
        }
    });
  ''';

  page.onConsole.listen((msg) async {
    if (blocked) return;
    if (msg.text == null) return;
    if (msg.text!.contains('!clicked_element!')) {
      // Get only the HTML of the clicked element
      String clickedElement = msg.text!.split('!clicked_element!')[1];
      // Block the browser from interacting with the page
      blocked = true;
      await page.evaluate(blockedJsSnippet);
      // Send a request to OpenAI assistant using python
      // The python script will return a response
      // To call the python script, use the Process class
      // with the following command:
      //    python lib/open_ai_assistant.py
      //      --name "username_input"
      //      --description "Login username input form field"
      //      --html "${clickedElement}"
      ProcessResult results = await Process.run(
        'python', [
          'lib/open_ai_assistant.py',
            '--name', '"username_input"',
            '--description', '"Login username input form field"',
            '--html', '"$clickedElement"'
        ],
      );
      // Parse the response from the python script
      // and display it in the console
      String result = results.stdout.toString();
      print(result);
      // Enable the user to interact with the page again
      blocked = false;
      await page.evaluate(jsSnippet);
    }
  });

  // Inject the snippet into the page
  await page.evaluate(blocked ? blockedJsSnippet : jsSnippet);
}