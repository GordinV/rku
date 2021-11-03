module.exports = {
    RECORDS_LIMIT: 1000,
    // таски
    // логи
    logs: {
        gridConfig: [
            {id: "kasutaja", name: "Kasutaja", width: "20%", show: true},
            {id: "koostatud", name: "Koostatud", width: "15%"},
            {id: "muudatud", name: "Muudatud", width: "15%"},
            {id: "prinditud", name: "Prinditud", width: "15%"},
            {id: "email", name: "Meilitud", width: "15%"},
            {id: "earve", name: "e-Arve", width: "15%"},
            {id: "kustutatud", name: "Kustutatud", width: "15%"}]

    },
    // отчет об исполнении
    tulemused: {
        gridConfig: [
            {id: "id", name: "id", width: "5%", show: false},
            {
                id: 'kas_vigane',
                name: 'Staatus',
                width: '5%',
                show: true,
                yesBackgroundColor: 'red',
                noBackgroundColor: 'green'
            },
            {id: "result", name: "Tulemused", width: "10%", show: false},
            {id: "error_message", name: "Teatis", width: "70%", show: true},
            {id: "viitenr", name: "Viitenumber", width: "15%", show: true}
        ]
    },
    START_MENU: {
        URL: '/newApi/startMenu'
    },
    REKL: {
        LIB_OBJS: [
            {id: 'asutused', filter: ``},
        ],
        URL: '/newApi/startMenu'
    },
    TEATIS: {
        toolbarProps: {
            btnAdd: {
                show: false,
                disabled: false
            }
        }
    },
    VORDER: {
        LIB_OBJS: [
            {id: 'kassa', filter: ''},
            {id: 'asutused', filter: `where id in (select asutusid from lapsed.vanemad)`},
            {id: 'nomenclature', filter: `where dok in ('VORDER')`}
        ]
    },

    // счета
    LEPING: {
        LIB_OBJS: [
            {id: 'nomenclature', filter: `where dok = 'ARV'`},
            {id: 'asutused', filter: ``},
            {id: 'objekt', filter: ``}
        ]
    },
    ANDMED: {
        LIB_OBJS: [
            {id: 'nomenclature', filter: `where dok = 'ARV'`},
            {id: 'leping', filter: ``}
        ]
    },

    // sorder
    SORDER: {
        LIB_OBJS: [
            {id: 'nomenclature', filter: `where dok = 'SORDER'`},
            {id: 'asutused', filter: ``},
            {id: 'kassa', filter: ``},
            {id: 'arv', filter: ``}
        ]
    },

    // счета
    ARV: {
        LIB_OBJS: [
            {id: 'nomenclature', filter: `where dok = 'ARV'`},
            {id: 'asutused', filter: ``}

        ],
        EVENTS: [
            {name: 'Häälestamine', method: null, docTypeId: null},
            {name: 'Trükk kõik valitud arved', method: null, docTypeId: null},
            {name: 'Email kõik valitud arved', method: null, docTypeId: null},
            {name: 'Saada E-Arved (Omniva) kõik valitud arved', method: null, docTypeId: null},
            {name: 'Saama XML e-arved kõik valitud arved', method: null, docTypeId: null},
            {name: 'Saama XML e-arved (SEB) kõik valitud arved', method: null, docTypeId: null},
            {name: 'Saama XML e-arved (SWED) kõik valitud arved', method: null, docTypeId: null},
        ]
    },
    NOMENCLATURE: {
        LIBRARIES: [],

        TAXIES: [
            {id: 2, kood: '0', name: '0%'},
            {id: 3, kood: '5', name: '5%'},
            {id: 4, kood: '10', name: '10%'},
            {id: 6, kood: '20', name: '20%'}
        ],

        UHIK: [
            {id: 1, kood: 'muud', name: 'Muud'},
            {id: 2, kood: 'tk', name: 'Tükk'},
            {id: 3, kood: 'päev', name: 'Päev'},
            {id: 4, kood: 'kuu', name: 'Kuu'},
            {id: 5, kood: 'aasta', name: 'Aasta'},
            {id: 6, kood: 'm3', name: 'M3'}
        ],

        ALGORITMID: [
            {id: 1, kood: 'päev', name: 'Päev'},
            {id: 2, kood: 'konstantne', name: 'Konstantne'},
            {id: 3, kood: 'külastamine', name: 'Külastamine'},
        ],

        TYYP: [
            {id: 2, kood: 'SOODUSTUS', name: ' '}
        ]

    },
    REKV: {
        LIB_OBJS: [
            {id: 'kontod', filter: ``},
            {id: 'asutuse_liik', filter: ''}
        ]
    },
    // нода для справочников
    LIBS: {
        POST_LOAD_LIBS_URL: '/newApi/loadLibs'
    },
    // нода для документов
    DOCS: {
        POST_LOAD_DOCS_URL: '/newApi/document'
    }


}
;