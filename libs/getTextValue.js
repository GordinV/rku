// will calculate sum of some field
const langFile = require('./../config/lang');
const DocContext = require('./../frontend/doc-context');


const getTextValue = (value, lang) => {
    if (!DocContext.keel) {
        DocContext.keel = 'EST';
    }

    let keel = DocContext.keel.toUpperCase() === 'EST' ? 1 : DocContext.keel.toUpperCase() === 'RU' ? 2 : 0;
    lang = lang ? lang : keel;
    return langFile[value] ? langFile[value][lang] : value;

};
module.exports = getTextValue;