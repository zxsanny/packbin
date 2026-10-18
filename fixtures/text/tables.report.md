# Compact text tables: size report

Held-out sentences (not used for training) and synthetic number messages; sizes are whole string fields.

| set | messages | chars | today (bytes) | compact (bytes) | compact / today | bits per char | bound | |
|-----|---------:|------:|--------------:|----------------:|----------------:|--------------:|------:|---|
| lower-ua | 1000 | 27775 | 52300 | 18575 | 35.5 % | 5.35 | 40 % | ok |
| lower-ru | 1000 | 31872 | 59824 | 20656 | 34.5 % | 5.18 | 40 % | ok |
| lower-en | 1000 | 37398 | 39398 | 22477 | 57.1 % | 4.81 | 62 % | ok |
| mixed | 1000 | 40917 | 65678 | 26409 | 40.2 % | 5.16 | 48 % | ok |
| raw-ua | 1000 | 27964 | 52698 | 19861 | 37.7 % | 5.68 | 40 % | ok |
| raw-ru | 1000 | 31457 | 59096 | 21417 | 36.2 % | 5.45 | 40 % | ok |
| raw-en | 1000 | 37340 | 39348 | 23536 | 59.8 % | 5.04 | 62 % | ok |
| numbers | 1000 | 15320 | 20642 | 10456 | 50.7 % | 5.46 | 56 % | ok |
| text+coords | 800 | 34927 | 56820 | 22137 | 39.0 % | 5.07 | 45 % | ok |
