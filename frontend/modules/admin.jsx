'use strict';

const React = require('react');
const PropTypes = require('prop-types');
const DocContext = require('./../doc-context.js');

const Menu = require('./../components/menu-toolbar/menu-toolbar.jsx');

const StartMenu = require('./../components/start-menu/start-menu.jsx'),
    AdminRegister = require('./../docs/admin/index.jsx'),
    UseridRegister = require('./../docs/userid/index.jsx'),
    UserDocument = require('./../docs/userid/document/index.jsx'),
    TaotlusLoginRegister = require('./../docs/taotlus_login/index.jsx'),
    TaotlusLoginDocument = require('./../docs/taotlus_login/document/index.jsx');


const {Route} = require('react-router-dom');
const {StyleRoot} = require('radium');
const MODULE = 'admin';

class App extends React.Component {
    constructor(props) {
        super(props);
        this.prepareParamsForToolbar = this.prepareParamsForToolbar.bind(this);
    }

    render() {

        return (
            <StyleRoot>
                <Route exact path="/admin"
                       render={(props) =>
                           <AdminRegister
                               history={props.history}
                               initData={this.props.initData}
                               module={MODULE}/>}/>
                <Route exact path="/admin/admin"
                       render={(props) => <AdminRegister history={props.history}
                                                         initData={this.props.initData}
                                                         module={MODULE}/>}/>
                <Route exact path="/admin/taotlus_login"
                       render={(props) => <TaotlusLoginRegister history={props.history}
                                                                initData={this.props.initData}
                                                                module={MODULE}/>}/>
                <Route exact path="/admin/taotlus_login/:docId"
                       render={(props) => <TaotlusLoginDocument  {...props}
                                                                 module={MODULE}
                                                                 history={props.history}/>}
                />
                <Route exact path="/admin/userid"
                       render={(props) => <UseridRegister history={props.history}
                                                                initData={this.props.initData}
                                                                module={MODULE}/>}/>
                <Route exact path="/admin/userid/:docId"
                       render={(props) => <UserDocument  {...props}
                                                                 module={MODULE}
                                                                 history={props.history}/>}
                />

            </StyleRoot>)
    }

    prepareParamsForToolbar() {
        return {
            btnStart: {
                show: true
            },
            btnLogin: {
                show: true,
                disabled: false
            },
            btnAccount: {
                show: true,
                disabled: false
            }

        };
    }

}

module.exports = App;