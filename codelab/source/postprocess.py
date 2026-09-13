"""Post-process claat's index.html: https font URLs, brand fonts, no default GA."""
import re, sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('href="//fonts.googleapis.com', 'href="https://fonts.googleapis.com')
s = re.sub(r'\s*<google-codelab-analytics[^>]*></google-codelab-analytics>', '', s)
s = s.replace('codelab-gaid=""\n', '')
s = s.replace('<meta name="theme-color" content="#4F7DC9">', '<meta name="theme-color" content="#1A73E8">')
brand = '''  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Google+Sans+Flex:opsz,wdth,wght,ROND@6..144,25..151,1..1000,0..100&family=Google+Sans+Code:wght@300..800&display=swap">
  <style>
    google-codelab, google-codelab *:not(.material-icons):not(i) {
      font-family: "Google Sans Flex", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    google-codelab code, google-codelab pre, google-codelab pre * {
      font-family: "Google Sans Code", "Roboto Mono", "Source Code Pro", monospace !important;
    }
    google-codelab-step h2.step-title { font-weight: 500; letter-spacing: -0.01em; }
    google-codelab-step h3 { font-weight: 500; }
    google-codelab-step table code { font-size: 0.92em; }
  </style>
'''
s = s.replace('</head>', brand + '</head>', 1)
open(p, 'w').write(s)
print('postprocessed')
