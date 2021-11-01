// will calculate sum of some field
const langFile = require('./../config/lang');
const DocContext = require('./../frontend/doc-context');


const getTextValue = (value, lang) => {
    let keel = DocContext.keel == 'EST' ? 1 : DocContext.keel == 'RU' ? 2 : 0;

    lang = lang ? lang : keel;

    return langFile[value] ? langFile[value][lang] : value;

};
module.exports = getTextValue;