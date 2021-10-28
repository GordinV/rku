'use strict';

const React = require('react');
const ReactServer = require('react-dom/server');
const getModule = require('./../../libs/getModule');
const menuModel = require('./../../models/ou/start-menu');

const {StaticRouter} = require('react-router');
const path = require('path');
const App = require('./../../frontend/modules/raama.jsx');
const DocContext = require('./../../frontend/doc-context');
const config = require('./../../config/ku');

const db = require('./../../libs/db');
const RECORDS_LIMIT = require('./../../config/constants').RECORDS_LIMIT;


exports.get = async (req, res) => {
    let documentType = 'raama',
        returnedDocType = documentType; //вернем обратно тип документа
    if (req.params.documentType) {
        documentType = req.params.documentType;
    }

    if (!documentType) {
        //вернет регистр документов
        documentType = 'raama';
    }

    let user = require('./../../middleware/userData')(req);  // check for userid in session

    // готовим загрузку конфигурации регистров
    let kataloog = './../../models/';
    const docConfig = {};

    DocContext.userData = user;
    DocContext.module = 'raama';

    Object.keys(config).forEach(key => {
        let folder = path.join(kataloog, config[key]);
        docConfig[key.toUpperCase()] = require(folder).grid.gridConfiguration;
    });

    const Doc = require('./../../classes/DocumentTemplate');
    const Document = new Doc(documentType, null, user.userId, user.asutusId, 'raama');
    // делаем запрос , получаем первоначальные данные
    let gridConfig = Document.config.grid.gridConfiguration;
    // вызвать метод

    const sqlData = {
        docTypeId: documentType,
        result: await Document.selectDocs([], '', RECORDS_LIMIT),
        menu: await db.queryDb(menuModel.sqlString, ['raama']),
        gridConfig: gridConfig,
        docConfig: docConfig,
        requiredFields: Document.requiredFields ? Document.requiredFields : [],
        subtotals: Document.config.grid.subtotals ? Document.config.grid.subtotals : []
    };

    DocContext.initData = sqlData;

    // усли указан конвертер, то отдаем данные туда на обработку
    if (Document.config.grid && Document.config.grid.converter) {
        sqlData.result.data = Document.config.grid.converter(sqlData.result.data);
    }
    let storeInitialData = JSON.stringify(sqlData);
    let userData = JSON.stringify(user);
    let context = {};


    const Component = React.createElement(
        StaticRouter,
        {context: context, location: req.url}, React.createElement(
            App,
            {initData: sqlData, userData: user, docConfig: docConfig}));

    try {
        let html = ReactServer.renderToString(Component);
        if (context.url) {
            res.writeHead(301, {
                location: context.url
            });
            res.end()
        } else {
            res.render('raama', {
                "title": documentType,
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

exports.post = async (req, res) => {
    let user = require('../middleware/userData')(req); // данные пользователя
    const documentType = req.params.documentType.toUpperCase(); // получим из параметра тип документа
    const docId = Number(req.params.id); //ид документа

    /*
        if (!user) {
            raise.error('No user', user);
            const err = new HttpError(err);
            if (err instanceof HttpError) {
                return res.send({"message": 'No user'});
            }
        }
    */

    if (!user) {
        user = {
            userId: 1,
            asutusId: 1
        }
    }

    const params = {
        documentType: documentType,
        docId: docId,
        user: user
    };

    const Doc = require('./../classes/DocumentTemplate');
    const Document = new Doc(documentType, docId, user.userId, user.asutusId);

    let data;

    // вызвать метод. Есди ИД = 0, то вызывается запрос на создание нового документа
    if (docId) {
        data = {result: await Document.select()};
    } else {
        data = {result: await Document.createNew()};
    }

    const preparedData = Object.assign({}, data.result.row,
        {gridData: data.result.details},
        {relations: data.result.relations},
        {gridConfig: data.result.gridConfig});

    res.send({params: params, data: [preparedData]});

    /*
        try {

            let data =  await db.queryDb(sqlString,params);
            // вернуть данные
            res.send(data);
        } catch (error) {
            console.error('error:', error); // @todo Обработка ошибок
            res.send({result:'Error'});

        }
    */
};

exports.put = async (req, res) => {
    let user = require('../middleware/userData')(req); // данные пользователя
    let documentType = req.params.documentType.toUpperCase(); // получим из параметра тип документа
    const docId = Number(req.params.id); //ид документа
    let data = req.body;

    /*
        if (!user) {
            raise.error('No user', user);
            const err = new HttpError(err);
            if (err instanceof HttpError) {
                return res.send({"message": 'No user'});
            }
        }
    */

    if (!user) {
        user = {
            userId: 1,
            asutusId: 1
        }
    }

    const params = {
        userId: user.userId,
        asutusId: user.asutusId,
        data: {data}
    };

    const Doc = require('./../classes/DocumentTemplate');
    const Document = new Doc(documentType, docId, user.userId, user.asutusId);

    let savedData = await Document.save(params);

    const prepairedData = Object.assign({}, savedData.row[0],
        {bpm: savedData.bpm ? savedData.bpm : []},
        {gridData: savedData.details ? savedData.details : []},
        {relations: savedData.relations ? savedData.relations : []},
        {gridConfig: savedData.gridConfig ? savedData.gridConfig : []});

    res.send({result: {error_code: 0, error_message: null, docId: prepairedData.id}, data: [prepairedData]}); //пока нет новых данных

    /*
        try {

            let data =  await db.queryDb(sqlString,params);
            // вернуть данные
            res.send(data);
        } catch (error) {
            console.error('error:', error); // @todo Обработка ошибок
            res.send({result:'Error'});

        }
    */
};