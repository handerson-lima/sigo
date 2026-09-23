Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:

diff --git a/firestore.rules b/firestore.rules
index 3dc3838..a7b1d06 100644
--- a/firestore.rules
+++ b/firestore.rules
@@ -40,7 +40,7 @@ service cloud.firestore {
   match /construtoras/{c} {
    allow read: if dev() || member(c);
    allow create: if dev() && request.resource.data.id == c;
-   allow update: if admin(c) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','cnpj','address','updatedAt']);
+   allow update: if admin(c) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','cnpj','address','logoUrl','updatedAt']);
    allow delete: if dev();
    match /construtora_members/{uid} { allow read: if signed() && (request.auth.uid == uid || admin(c)); allow write: if dev(); }
    match /commands/{id} { allow read: if dev() || (signed() && resource.data.actor == request.auth.uid); allow write: if dev(); }
diff --git a/functions/package-lock.json b/functions/package-lock.json
index 625e18c..9ddfdf1 100644
--- a/functions/package-lock.json
+++ b/functions/package-lock.json
@@ -7,10 +7,12 @@
       "name": "functions",
       "dependencies": {
         "firebase-admin": "^12.1.0",
-        "firebase-functions": "^5.0.0"
+        "firebase-functions": "^5.0.0",
+        "sharp": "^0.35.4"
       },
       "devDependencies": {
         "@firebase/rules-unit-testing": "5.0.2",
+        "@types/sharp": "^0.31.1",
         "firebase": "12.19.0",
         "firebase-tools": "15.30.1",
         "playwright": "1.63.0",
@@ -80,6 +82,16 @@
         "@electric-sql/pglite": "0.3.16"
       }
     },
+    "node_modules/@emnapi/runtime": {
+      "version": "1.11.3",
+      "resolved": "https://registry.npmjs.org/@emnapi/runtime/-/runtime-1.11.3.tgz",
+      "integrity": "sha512-Xz4Tpyki7XyrpbUK1jR1AhdAdaXyhhY4lZ3neLodmhpuWfy2PAQN5B46sAiU4liOXGLkHypn/qU+jvfWSCYYLA==",
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "tslib": "^2.4.0"
+      }
+    },
     "node_modules/@fastify/busboy": {
       "version": "3.2.2",
       "resolved": "https://registry.npmjs.org/@fastify/busboy/-/busboy-3.2.2.tgz",
@@ -2501,6 +2513,554 @@
         "hono": "^4"
       }
     },
+    "node_modules/@img/colour": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/@img/colour/-/colour-1.1.0.tgz",
+      "integrity": "sha512-Td76q7j57o/tLVdgS746cYARfSyxk8iEfRxewL9h4OMzYhbW4TAcppl0mT4eyqXddh6L/jwoM75mo7ixa/pCeQ==",
+      "license": "MIT",
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/@img/sharp-darwin-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-arm64/-/sharp-darwin-arm64-0.35.4.tgz",
+      "integrity": "sha512-Uhfl4V4lhP2nbUVF9+hyH1+luj86f1gUFeo8ALYxFoULoU+G87D43BfeMP8XHsk9boxAnCY/bf2EHwhA7MuGsA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-darwin-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-x64/-/sharp-darwin-x64-0.35.4.tgz",
+      "integrity": "sha512-hWniXY3bG5qKpkKrAwPe4y+VTPmf086YQAnkxWh7uA1YrlRouWGa0M0Mxj3ZjnXFkv7/TD1bTy9lGUK26vRvWw==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-freebsd-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-freebsd-wasm32/-/sharp-freebsd-wasm32-0.35.4.tgz",
+      "integrity": "sha512-lIsKw/BU+kjB4eZjxrYrZmwOJYi3Ajrv66iAlBmUPyKc3HpnloevB1g3wxGD9P/5BbQ1brBGl65VRRrCvQDEqA==",
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "freebsd"
+      ],
+      "dependencies": {
+        "@img/sharp-wasm32": "0.35.4"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-arm64/-/sharp-libvips-darwin-arm64-1.3.3.tgz",
+      "integrity": "sha512-suTBPTDGrI9WodccaDdwZItTSaBYASlBk1NSfElSHrUfzu3szG6lvIF58+WiFvnfzuK8ZBFS5zE00PxqxnRiPg==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-x64/-/sharp-libvips-darwin-x64-1.3.3.tgz",
+      "integrity": "sha512-FVJZ5mITMobmXIz/hPDTw0EintTW5H3WfrxwLqEqjiIihlu+hVRyGrFQ60xl0Lxn7Bt3zdpevPaQi0HEzqz9fw==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm/-/sharp-libvips-linux-arm-1.3.3.tgz",
+      "integrity": "sha512-3rbU4vqXXc3hY/OiXdl52xZvT0F1yEngWfvqudtPJg/KkyiaQw2DRsFrNzpmLvfavbwOq3qXn36GP8obHRULQA==",
+      "cpu": [
+        "arm"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm64/-/sharp-libvips-linux-arm64-1.3.3.tgz",
+      "integrity": "sha512-0DaL0A6Xu6sQSQFwe4iVCrKWU2cCTItnRsYsCdxAMm9NF6twAA9BKnoqy4hqz4+azQ0JHuA26qiUKsf1XJ/v5A==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-ppc64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-ppc64/-/sharp-libvips-linux-ppc64-1.3.3.tgz",
+      "integrity": "sha512-cdn1OvUBwsXhbC0zSzJnNzf5MZ/mTrobawDvNXBTxe8VtqKAm0sRuEY2Evzovb/w9JMk4TvRxqt1mekSuJz64w==",
+      "cpu": [
+        "ppc64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-riscv64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-riscv64/-/sharp-libvips-linux-riscv64-1.3.3.tgz",
+      "integrity": "sha512-HjPVx7yKz+0lqdhDlTw1tt90wamBoxhiXpvl1XZpJLiHH4RCJ5yDTqH+VlYPv2fwFs89JFw4c1IexYOcQUi4IQ==",
+      "cpu": [
+        "riscv64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-s390x": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-s390x/-/sharp-libvips-linux-s390x-1.3.3.tgz",
+      "integrity": "sha512-neWLh+3yCNThxnfy3c4BbVBeGgt9aftno+XbT56iK28RgeDs3UOFWviLWlUu0bArYVYJaFDK+RRohbicUNCm8Q==",
+      "cpu": [
+        "s390x"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-x64/-/sharp-libvips-linux-x64-1.3.3.tgz",
+      "integrity": "sha512-4vKmvAst9nrowcqquKFAyZJUDolUaIp8uRiN0mWFguJ1IplC9/pitXtlnnlU4aa/eJw3J7i67V+pwUL+wZGdsA==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-arm64/-/sharp-libvips-linuxmusl-arm64-1.3.3.tgz",
+      "integrity": "sha512-Y9kQaLMuNoB0bPYOOdcZMaseNrFpPodIWWMrx+CZyydf2xn68j9WYc6sWWRrDwNkzCQjKYfc68L7jKjGlHMibw==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-x64/-/sharp-libvips-linuxmusl-x64-1.3.3.tgz",
+      "integrity": "sha512-fj8Mv0HHfD1Rr+4I68+3agJynxDWtBFgicTbSOb9Bke6pIwzGcJ+RX/yHjmiEGFMCavY/dxvem7MyNaJF+wDiw==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm/-/sharp-linux-arm-0.35.4.tgz",
+      "integrity": "sha512-7OAS8gI0EReKGVN2HssHlM6umJgxF5VI3xN0p9FA91p/YO+ou5hiNghLdZ5BEHztwaaK5+bLKRf8x/o2L2nk9A==",
+      "cpu": [
+        "arm"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm64/-/sharp-linux-arm64-0.35.4.tgz",
+      "integrity": "sha512-De4jpEnAU8Hd5oT0j1G3uL4ZvTuipVMn7YC6vPaJhy6/7EwEae0SVAoBrUMYQbkLGDm85taVWwuPc1a44LTzCQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-ppc64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-ppc64/-/sharp-linux-ppc64-0.35.4.tgz",
+      "integrity": "sha512-2oYZJeIl4kCcMGk4ouZVjnkCtFrpQFlNEtJ6GbxzhHQchwH0NH/qEb9ykmOl29dqwMq+JhFdZn+1ak2FKhI9fQ==",
+      "cpu": [
+        "ppc64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-ppc64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-riscv64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-riscv64/-/sharp-linux-riscv64-0.35.4.tgz",
+      "integrity": "sha512-cPbNChoRURAWdebDIHSenxRpgEdy7JkPydSnUxRm9VvKD7m0/xVaR/8Fzlu81pk5nHEvHH87UZUA7cTtwnbJSA==",
+      "cpu": [
+        "riscv64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-riscv64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-s390x": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-s390x/-/sharp-linux-s390x-0.35.4.tgz",
+      "integrity": "sha512-RY0JFY8Fd6RonCBtHz+DvadaPkXDSI1AUn6yWL9TipqkZ1vY8w8evqdgyDFnkm4/K1ve1TvZiaePP5oSd4+WVQ==",
+      "cpu": [
+        "s390x"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-s390x": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-x64/-/sharp-linux-x64-0.35.4.tgz",
+      "integrity": "sha512-9qvvEAuk8k89TfWUoX2htWjbAMX8p+NxCppjpcg5k6xMsjhBQPTsoIh36h9Qde4WRuGpJeYnOjdosDn/cnv+OA==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-arm64/-/sharp-linuxmusl-arm64-0.35.4.tgz",
+      "integrity": "sha512-KB5jxpfWQTr0nc3xdHtWChdbifHrBGsd2SM62Eyxrl8afikm+f5qGBU75SJIZBT/S1MC8XyacdlXBMSWq6OURA==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-x64/-/sharp-linuxmusl-x64-0.35.4.tgz",
+      "integrity": "sha512-f+eZJZIQNEEd26RPSW+76chwOf1XtA2Y/O+5ocVyLliHkeih3e+jhLVBdNTd2rS3IbNXK8+ug93Vf5ZXtF5Lxg==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-wasm32/-/sharp-wasm32-0.35.4.tgz",
+      "integrity": "sha512-zQnl4Kwp7Q6NHsENtU2T/00Zi+w3AQNwz3+UaTyVBy2FpXrzXzGjndpK61onhZjRtRpQXxCTeqw19bVyXOh7jA==",
+      "license": "Apache-2.0 AND LGPL-3.0-or-later AND MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/runtime": "^1.11.3"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-webcontainers-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-webcontainers-wasm32/-/sharp-webcontainers-wasm32-0.35.4.tgz",
+      "integrity": "sha512-ESfNkywmCfPNyaZjxooddJQiQ+l/nTpGEOGthxiLnIHXC/CmcBixnfwUleX9mCz9ovrUUvKMap/pm8RYbzfwaA==",
+      "cpu": [
+        "wasm32"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "dependencies": {
+        "@img/sharp-wasm32": "0.35.4"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-arm64/-/sharp-win32-arm64-0.35.4.tgz",
+      "integrity": "sha512-iNdlBX9gLVvqe2I3uIJSIKTq6wckP/DYxZtcqxm09x5Gi24DnFBmPAWZmr60ZyYMG0xlzo6goG3670ar+RXvRw==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-ia32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-ia32/-/sharp-win32-ia32-0.35.4.tgz",
+      "integrity": "sha512-kqRsbaa5CS6KHlpxnN7WhE6vAAugXyZButpRdvDWetlv6Qv4N9WTcrWzF7tXfB9T7MsoadqdI8hmwLq6UlLvtw==",
+      "cpu": [
+        "ia32"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": "^20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-x64/-/sharp-win32-x64-0.35.4.tgz",
+      "integrity": "sha512-XtmnYhBcrORsJ4XJngyzr/EWP0hRZLAZRFaApdKuviyqF78+ylxh2y06ZmtULAMOnObJ3ucpN0AcwSWnMowTRg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
     "node_modules/@inquirer/ansi": {
       "version": "1.0.2",
       "resolved": "https://registry.npmjs.org/@inquirer/ansi/-/ansi-1.0.2.tgz",
@@ -3804,6 +4364,16 @@
         "@types/node": "*"
       }
     },
+    "node_modules/@types/sharp": {
+      "version": "0.31.1",
+      "resolved": "https://registry.npmjs.org/@types/sharp/-/sharp-0.31.1.tgz",
+      "integrity": "sha512-5nWwamN9ZFHXaYEincMSuza8nNfOof8nmO+mcI+Agx1uMUk4/pQnNIcix+9rLPXzKrm1pS34+6WRDbDV0Jn7ag==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@types/node": "*"
+      }
+    },
     "node_modules/@types/tough-cookie": {
       "version": "4.0.5",
       "resolved": "https://registry.npmjs.org/@types/tough-cookie/-/tough-cookie-4.0.5.tgz",
@@ -5434,6 +6004,15 @@
         "npm": "1.2.8000 || >= 1.4.16"
       }
     },
+    "node_modules/detect-libc": {
+      "version": "2.1.2",
+      "resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.1.2.tgz",
+      "integrity": "sha512-Btj2BOOO83o3WyH59e8MgXsxEQVcarkUOpEYrubB0urwnN10yQ364rsiByU11nZlqWYZm05i/of7io4mzihBtQ==",
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=8"
+      }
+    },
     "node_modules/discontinuous-range": {
       "version": "1.0.0",
       "resolved": "https://registry.npmjs.org/discontinuous-range/-/discontinuous-range-1.0.0.tgz",
@@ -9816,6 +10395,55 @@
       "integrity": "sha512-E5LDX7Wrp85Kil5bhZv46j8jOeboKq5JMmYM3gVGdGH8xFpPWXUMsNrlODCrkoxMEeNi/XZIwuRvY4XNwYMJpw==",
       "license": "ISC"
     },
+    "node_modules/sharp": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/sharp/-/sharp-0.35.4.tgz",
+      "integrity": "sha512-n++8XWcj+jCOr2IOl7h8LbKnGBDY4aPbmprMONBNFdn0ImXqpGVv5zliDs0V9HbmbCQLpbuo2ej9rAoOQTvMDA==",
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@img/colour": "^1.1.0",
+        "detect-libc": "^2.1.2",
+        "semver": "^7.8.5"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-darwin-arm64": "0.35.4",
+        "@img/sharp-darwin-x64": "0.35.4",
+        "@img/sharp-freebsd-wasm32": "0.35.4",
+        "@img/sharp-libvips-darwin-arm64": "1.3.3",
+        "@img/sharp-libvips-darwin-x64": "1.3.3",
+        "@img/sharp-libvips-linux-arm": "1.3.3",
+        "@img/sharp-libvips-linux-arm64": "1.3.3",
+        "@img/sharp-libvips-linux-ppc64": "1.3.3",
+        "@img/sharp-libvips-linux-riscv64": "1.3.3",
+        "@img/sharp-libvips-linux-s390x": "1.3.3",
+        "@img/sharp-libvips-linux-x64": "1.3.3",
+        "@img/sharp-libvips-linuxmusl-arm64": "1.3.3",
+        "@img/sharp-libvips-linuxmusl-x64": "1.3.3",
+        "@img/sharp-linux-arm": "0.35.4",
+        "@img/sharp-linux-arm64": "0.35.4",
+        "@img/sharp-linux-ppc64": "0.35.4",
+        "@img/sharp-linux-riscv64": "0.35.4",
+        "@img/sharp-linux-s390x": "0.35.4",
+        "@img/sharp-linux-x64": "0.35.4",
+        "@img/sharp-linuxmusl-arm64": "0.35.4",
+        "@img/sharp-linuxmusl-x64": "0.35.4",
+        "@img/sharp-webcontainers-wasm32": "0.35.4",
+        "@img/sharp-win32-arm64": "0.35.4",
+        "@img/sharp-win32-ia32": "0.35.4",
+        "@img/sharp-win32-x64": "0.35.4"
+      },
+      "peerDependenciesMeta": {
+        "@types/node": {
+          "optional": true
+        }
+      }
+    },
     "node_modules/shebang-command": {
       "version": "2.0.0",
       "resolved": "https://registry.npmjs.org/shebang-command/-/shebang-command-2.0.0.tgz",
diff --git a/functions/package.json b/functions/package.json
index 522d6db..70be4d3 100644
--- a/functions/package.json
+++ b/functions/package.json
@@ -22,10 +22,12 @@
   "main": "lib/index.js",
   "dependencies": {
     "firebase-admin": "^12.1.0",
-    "firebase-functions": "^5.0.0"
+    "firebase-functions": "^5.0.0",
+    "sharp": "^0.35.4"
   },
   "devDependencies": {
     "@firebase/rules-unit-testing": "5.0.2",
+    "@types/sharp": "^0.31.1",
     "firebase": "12.19.0",
     "firebase-tools": "15.30.1",
     "playwright": "1.63.0",
diff --git a/functions/src/index.ts b/functions/src/index.ts
index 0691671..2d9314a 100644
--- a/functions/src/index.ts
+++ b/functions/src/index.ts
@@ -328,3 +328,29 @@ export const finalizeDiario = callable('finalizeDiario', async (d, uid) => {
     tx.create(command, {payloadHash: h, result, actor: uid, at: stamp()}); audit(tx, uid, 'finalizeDiario', ref.path); return result;
   });
 });
+
+export const processLogo = functions.storage.object().onFinalize(async (object) => {
+  if (!object.name || !object.name.match(/^construtoras\/[^\/]+\/logos\/[^\/]+$/)) return;
+  if (object.metadata?.processed === 'true') return;
+
+  const bucket = admin.storage().bucket(object.bucket);
+  const file = bucket.file(object.name);
+  const [metadata] = await file.getMetadata();
+
+  if (!metadata.contentType?.startsWith('image/')) return;
+
+  const [buffer] = await file.download();
+  // @ts-ignore
+  const sharp = (await import('sharp')).default || (await import('sharp'));
+  
+  const processedBuffer = await sharp(buffer)
+    .resize({ width: 2000, height: 2000, fit: 'inside', withoutEnlargement: true })
+    .toBuffer();
+
+  await file.save(processedBuffer, {
+    metadata: {
+      contentType: metadata.contentType,
+      metadata: { processed: 'true' }
+    }
+  });
+});
diff --git a/storage.rules b/storage.rules
index e539566..d092b09 100644
--- a/storage.rules
+++ b/storage.rules
@@ -5,7 +5,13 @@ service firebase.storage {
   function dev() { return signed() && firestore.exists(/databases/(default)/documents/dev_roles/$(request.auth.uid)) && firestore.get(/databases/(default)/documents/dev_roles/$(request.auth.uid)).data.get('isActive', false) == true; }
   function cm(c) { return firestore.get(/databases/(default)/documents/construtoras/$(c)/construtora_members/$(request.auth.uid)).data; }
   function om(c,o) { return firestore.get(/databases/(default)/documents/construtoras/$(c)/obras/$(o)/members/$(request.auth.uid)).data; }
+  function admin(c) { return dev() || (signed() && cm(c).get('isActive',false) == true && (cm(c).get('isAdmin',false) == true || cm(c).get('isOwner',false) == true || cm(c).get('role', '') == 'admin' || cm(c).get('role', '') == 'owner')); }
   function access(c,o) { return dev() || (signed() && cm(c).get('isActive',false) == true && (cm(c).get('isAdmin',false) == true || cm(c).get('isOwner',false) == true || (om(c,o).get('isActive',false) == true && (om(c,o).get('isAdmin',false) == true || om(c,o).get('isOwner',false) == true || 'diario' in om(c,o).get('modules',[]) || 'rdo' in om(c,o).get('modules',[]) || 'validacao' in om(c,o).get('modules',[]) || 'qualidade' in om(c,o).get('modules',[]) || 'epi' in om(c,o).get('modules',[]) || 'adm' in om(c,o).get('modules',[]) || 'financeiro' in om(c,o).get('modules',[]) || 'compras' in om(c,o).get('modules',[]) || 'almoxarifado' in om(c,o).get('modules',[]))))); }
+  match /construtoras/{c}/logos/{filename} {
+   allow read: if true;
+   allow create, update: if admin(c) && request.resource.size > 0 && request.resource.size <= 2 * 1024 * 1024 && request.resource.contentType.matches('image/(jpeg|png|webp)');
+   allow delete: if admin(c);
+  }
   match /construtoras/{c}/obras/{o}/diarios/{diary}/{uid}/{attachment} {
    allow read: if access(c,o);
    allow create: if resource == null && access(c,o) && request.auth.uid == uid && request.resource.size > 0 && request.resource.size <= 10 * 1024 * 1024 && request.resource.contentType.matches('image/(jpeg|png|webp)') && request.resource.metadata.keys().hasOnly(['sha256','owner']) && request.resource.metadata.owner == uid && request.resource.metadata.sha256.matches('^[a-f0-9]{64}$');

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
