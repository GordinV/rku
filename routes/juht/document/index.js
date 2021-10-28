'use strict';

const React = require('react');
const ReactServer = require('react-dom/server');
const {StaticRouter} = require('react-router');

exports.get = async (req, res) => {
    // рендер грида на сервере при первой загрузке странице
    // берем тип документа из параметра в адресе
    let documentType = req.params.documentType.toLowerCase(),
        docId = Number(req.params.id);


    const DocumentView = require(`./../../../frontend/docs/${documentType}/document/index.jsx`);
    let user = require('./../../../middleware/userData')(req);  // check for userid in session


    const Doc = require('./../../../classes/DocumentTemplate');
    const Document = new Doc(documentType, docId, user.userId, user.asutusId);

    // делаем запрос , получаем первоначальные данные
    // вызвать метод
    let data = {},
        context = {};

    if (docId) {
        data = await Document.select();
    } else {
        data = await Document.createNew();
    }
    // если задан бизнес процесс отправим его на форму
    const bpm = Document.config.bpm ? Document.config.bpm.filter(task => task.type === 'manual') : [];

    const prepairedData = Object.assign({}, data.row[0],
        {gridData: data.details},
        {relations: data.relations},
        {gridConfig: data.gridConfig},
        {bpm: bpm},
    );

    const Component = React.createElement(
        StaticRouter,
        {context: context, location: req.url}, React.createElement(
            DocumentView,
            {id: 'doc', initData: prepairedData, userData: user, docId: docId}));

    try {
        // передатим в хранилище данные
        let storeInitialData = JSON.stringify(prepairedData);
        let userData = JSON.stringify(user);

        let html = ReactServer.renderToString(Component);
        if (context.url) {
            res.writeHead(301, {
                location: context.url
            });
            res.end()
        } else {
            res.render('juht', {
                "title": 'Module juhataja',
                "user": user,
                "userData": userData,
                "store": storeInitialData
                , react: html
            });
        }
    } catch (e) {
        console.error('error:', e);
        res.statusCode = 500;
    }

};
