# Scenarios — scheme-depth-probe

| id | actor / trigger / state | behavior | status | AC |
|----|------------------------|----------|--------|----|
| S1 | maintainer runs the probe, a package builds the deep scheme | `built`, pack hex, unpack `same` | confirmed | AC-1 |
| S2 | a package refuses the deep scheme | `refused: <message>` | confirmed | AC-1 |
| S3 | the runtime raises a catchable stack error | `threw: <type>` | confirmed | AC-2 |
| S4 | the process dies | `crashed: <status>` and the next case runs | confirmed | AC-2 |
| S5 | a case hangs | `crashed: timeout` after 60 s | confirmed | AC-2 |
| S6 | second run on the same checkout | same lines, no file written | confirmed | AC-4 |
