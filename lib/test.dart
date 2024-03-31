


import 'dart:io';

void main() async {
  String html = """<div class="score-key-figures" style="background-color: rgba(255, 0, 0, 0.3);"><div class="score-key-figure"><div class="score-key-figure-title"><span class="score-key-figure-value">766</span><span class="score-key-figure-supplemental"></span></div><div class="score-key-figure-label">likes</div></div><div class="score-key-figure"><div class="score-key-figure-title"><span class="score-key-figure-value">140</span><span class="score-key-figure-supplemental">/ 140</span></div><div class="score-key-figure-label">pub points</div></div><div class="score-key-figure"><div class="score-key-figure-title"><span class="score-key-figure-value">99</span><span class="score-key-figure-supplemental">%</span></div><div class="score-key-figure-label">popularity</div></div></div>""";
  ProcessResult results = Process.runSync(
    'python3',
    [
      'open_ai_assistant.py',
      '--name',
      '"like count"',
      '--description',
      '"selector to like count field"',
      '--html',
      '"$html"'
    ],
  );
  String result = results.stdout.toString();
  print(result);
}