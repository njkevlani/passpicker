package pass

import (
	"reflect"
	"testing"
)

func TestParseTree(t *testing.T) {
	// A sample tree output with colors (ANSI escapes) and non-breaking spaces
	input := `Password Store
├── personal
│   ├── actcorp.in
│   │   └── 102701828364
│   ├── adda
│   │   └── njkevlani@gmail.com
│   ├── cashkro
│   └── equitas.bank.in
│       └── njkevlani
└── sharechat
    ├── google.com
    │   └── nileshkevlani@sharechat.co
    └── smartworks`

	expected := []string{
		"personal/actcorp.in/102701828364",
		"personal/adda/njkevlani@gmail.com",
		"personal/cashkro",
		"personal/equitas.bank.in/njkevlani",
		"sharechat/google.com/nileshkevlani@sharechat.co",
		"sharechat/smartworks",
	}

	result := parseTree(input)
	if !reflect.DeepEqual(result, expected) {
		t.Errorf("Expected:\n%v\nGot:\n%v", expected, result)
	}
}

// tree(1) drops to ASCII line drawing without a UTF-8 locale (GUI launches).
func TestParseTreeASCII(t *testing.T) {
	input := `Password Store
|-- personal
|   |-- actcorp.in
|   |   ` + "`" + `-- 102701828364
|   |-- cashkro
|   ` + "`" + `-- equitas.bank.in
|       ` + "`" + `-- njkevlani
` + "`" + `-- sharechat
    |-- google.com
    |   ` + "`" + `-- nileshkevlani@sharechat.co
    ` + "`" + `-- smartworks`

	expected := []string{
		"personal/actcorp.in/102701828364",
		"personal/cashkro",
		"personal/equitas.bank.in/njkevlani",
		"sharechat/google.com/nileshkevlani@sharechat.co",
		"sharechat/smartworks",
	}

	result := parseTree(input)
	if !reflect.DeepEqual(result, expected) {
		t.Errorf("Expected:\n%v\nGot:\n%v", expected, result)
	}
}

// gopass tree output has trailing slashes on directory names and 'gopass' as root.
func TestParseTreeGopass(t *testing.T) {
	input := `gopass
├── personal/
│   ├── actcorp.in/
│   │   └── 102701828364
│   ├── cashkro
│   └── equitas.bank.in/
│       └── njkevlani
└── sharechat/
    ├── google.com/
    │   └── nileshkevlani@sharechat.co
    └── smartworks`

	expected := []string{
		"personal/actcorp.in/102701828364",
		"personal/cashkro",
		"personal/equitas.bank.in/njkevlani",
		"sharechat/google.com/nileshkevlani@sharechat.co",
		"sharechat/smartworks",
	}

	result := parseTree(input)
	if !reflect.DeepEqual(result, expected) {
		t.Errorf("Expected:\n%v\nGot:\n%v", expected, result)
	}
}

