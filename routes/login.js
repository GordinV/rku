'use strict';

const userid = require('../models/userid'),
    async = require('async'),
    HttpError = require('./../error').HttpError,
    uuid = require('uuid/v1'),
    errorMessage = '';
const _ = require('lodash');
const DocContext = require('./../frontend/doc-context');



exports.get = function (req, res) {
    res.render('login', {"title": 'login', "errorMessage": errorMessage});
};

exports.post = function (req, res, next) {

    let username = req.body.username,
        password = req.body.password,
        errorMessage,
        statusCode = 200;

    let user = {};

    async.waterfall([
            function (callback) {
                //Loooking for acccount and loading login data
                let rekvId = null;

                userid.getUserId(username, rekvId, function (err, kasutaja) {
                    if (err) {
                        console.error('err',err);
                        return callback(err, null);
                    }

                    if (!kasutaja) {
                        const err = new HttpError(403, 'No user');
                        return callback(err, null);
                    }

                    errorMessage = null;

                    if (!req.session.users) {
                        req.session.users = [];
                    }

                    // user not loged In before
                    const newUser = Object.assign({
                        uuid: uuid(),
                        userId: kasutaja.id,
                        userName: kasutaja.ametnik,
                        asutusId: kasutaja.rekvid,
                        lastLogin: kasutaja.last_login,
                        userAccessList: kasutaja.allowed_access,
                        login: kasutaja.kasutaja,
                        parentid: kasutaja.parentid,
                        parent_asutus: kasutaja.parent_asutus,
                        roles: kasutaja.roles
                    }, kasutaja);

                    req.session.users.push(newUser);
                    user = newUser;

                    return callback(null, newUser);
                });
            },
            // checking for password
            function (kasutaja, callback) {
                userid.updateUserPassword(username, password, kasutaja.parool, function (err, result) {
                    if (err) return callback(err, null, null);
                    let error;

                    if (!result) {
                        error = new HttpError(403, 'Vale parool või kasutaja nimi');
                        errorMessage = 'Vale parool või kasutaja nimi';
                        statusCode = 403;
                        console.error('Vale parool või kasutaja nimi');
                        // return next(err);
                    }
                    return callback(error, result, kasutaja);

                });
            },

            // saving last login timestamp
            function (result, kasutaja, callback) {
                if (result) {
                    userid.updateUseridLastLogin(kasutaja.id, function (err, result) {
                        return callback(err, kasutaja, result);
                    });
                }
            },
            //load allowed asutused
            function (kasutaja, result, callback) {
                userid.loadPermitedAsutused(username, function (err, result) {
                    if (err) {
                        console.error(err);
                        return callback(err, null);
                    }

                    let userIndex = _.findIndex(req.session.users, {id: kasutaja.id});

                    //will set the list of allowed asutused to session object
                    req.session.users[userIndex].userAllowedAsutused = result;

                    callback(err, result);
                });

            }

        ],


        // finished
        function (err) {
            if (err) return next(err);

            if (errorMessage) {
                //back to login
                res.statusCode = statusCode;
                res.redirect('/login');
            } else {
                // open main page
                req.app.locals.user = user;
                //@todo привести в норму
                let role = '';
                 role = user.roles.is_kasutaja ? 'kasutaja': role;
                 role = user.roles.is_raama ? 'raama': role;
                 role = user.roles.is_admin ? 'admin': role;
                 role = user.roles.is_juht ? 'juht': role;

                switch(role) {
                    case 'kasutaja':
                        DocContext.pageName = 'Kasutaja'
                        res.redirect('/kasutaja');
                        break;
                    case 'admin':
                        DocContext.pageName = 'Administraator'
                        res.redirect('/admin');
                        break;
                    case 'raama':
                        DocContext.pageName = 'Raamatupidamine'
                        res.redirect('/raama');
                        break;
                    case 'juht':
                        DocContext.pageName = 'Juhataja'
                        res.redirect('/juht');
                        break;
                    default:
                        res.statusCode = 403;
                        res.redirect('/login');
                }


            }
        });
};