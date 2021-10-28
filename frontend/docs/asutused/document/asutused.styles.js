module.exports = {
    docRow: {
        display: 'flex',
        flexDirection: 'row',
/*
        border: '1px solid blue'
*/
    },
    docColumn: {
        display: 'flex',
        flexDirection: 'column',
/*
        border: '1px solid yellow',
*/
        width: '50%'
    },
    doc: {
        display: 'flex',
        flexDirection: 'column',
/*
        border: '1px solid brown'
*/
    },
    grid: {
        mainTable: {
            width: '100%',
            td: {
                border: '1px solid lightGrey',
                display: 'table-cell',
                paddingLeft: '5px',
            },
        },
        headerTable: {
            width:'100%',
        },

        gridContainer: {
            width: '100%'
        }

    },
};