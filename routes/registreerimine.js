const taotlus = require('../models/ou/taotlus_login'),
    async = require('async'),
    HttpError = require('./../error').HttpError,
    uuid = require('uuid/v1'),
    errorMessage = '';
const _ = require('lodash');


exports.get = function (req, res) {
    res.render('registreerimine', {"title": 'Uue kasutajana registreerimine', "errorMessage": errorMessage});
};

exports.edukalt = function (req, res) {
    res.render('edukalt', {"title": 'Uue kasutajana registreerimine', "errorMessage": errorMessage});
};

exports.post = async function (req, res, next) {

    let username = req.body.username,
        password = req.body.password,
        nimi = req.body.nimi,
        aadress = req.body.aadress,
        email = req.body.email,
        tel = req.body.tel,
        errorMessage,
        statusCode = 200;

    let user = {};
    const data = {
        id: 0,
        kasutaja: req.body.username,
        password: req.body.password,
        nimi: req.body.nimi,
        aadress: req.body.aadress,
        email: req.body.email,
        tel: req.body.tel,
    }

    const params = {
        userId: 999999,
        asutusId: 999999,
        data: {data}
    };

// salvestan
    const Doc = require('./../classes/DocumentTemplate');
    const Document = new Doc('TAOTLUS_LOGIN'.toLowerCase(), 0, null, null, 'ku');
    const savedData = await Document.save(params);

    if (!savedData.error_code && savedData.error_code > 0) {
        throw new Error('Salvestamine ebaõnnestus', savedData.error_message);
    } else {
        res.statusCode = 200;
        res.redirect('/edukalt');
    }

}
;