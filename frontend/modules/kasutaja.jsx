'use strict';

const React = require('react');
const PropTypes = require('prop-types');
const DocContext = require('./../doc-context.js');

const Menu = require('./../components/menu-toolbar/menu-toolbar.jsx');

const StartMenu = require('./../components/start-menu/start-menu.jsx'),
    KasutajaRegister = require('./../docs/kasutaja/index.jsx'),
    TaotlusLoginRegister = require('./../docs/taotlus_login/index.jsx'),
    TaotlusLoginDocument = require('./../docs/taotlus_login/document/index.jsx'),
    ObjectDocument = require('../docs/objekt/document/index.jsx'),
    ObjectRegister = require('./../docs/objekt/index.jsx'),
    LepingDocument = require('../docs/leping/document/index.jsx'),
    LepingRegister = require('./../docs/leping/index.jsx'),
    ArvDocument = require('../docs/arv/document/index.jsx'),
    ArvRegister = require('./../docs/arv/index.jsx'),
    SmkDocument = require('../docs/smk/document/index.jsx'),
    SorderDocument = require('../docs/sorder/document/index.jsx'),
    MooduDocument = require('../docs/moodu/document/index.jsx'),
    MooduRegister = require('./../docs/moodu/index.jsx');


const {Route} = require('react-router-dom');
const {StyleRoot} = require('radium');
const MODULE = 'kasutaja';

class App extends React.Component {
    constructor(props) {
        super(props);
        this.prepareParamsForToolbar = this.prepareParamsForToolbar.bind(this);
    }

    /*
        render() {
            return <div>Raama</div>
        }
    */
    render() {
        return (
            <StyleRoot>
                <Route path='/redirect' component={() => {
                    window.open(`http://${DocContext.link}`,"_blank")
                    return null;
                }}/>
                <Route exact path="/kasutaja"
                       render={(props) =>
                           <KasutajaRegister
                               history={props.history}
                               initData={this.props.initData}
                               module={MODULE}/>}/>
                <Route exact path="/kasutaja/kasutaja"
                       render={(props) => <KasutajaRegister history={props.history}
                                                         initData={this.props.initData}
                                                         module={MODULE}/>}
                />
                <Route exact path="/kasutaja/taotlus_login"
                       render={(props) => <TaotlusLoginRegister history={props.history}
                                                                initData={this.props.initData}
                                                                module={MODULE}/>}
                />
                <Route exact path="/kasutaja/taotlus_login/:docId"
                       render={(props) => <TaotlusLoginDocument  {...props}
                                                                 module={MODULE}
                                                                 history={props.history}/>}
                />
                <Route exact path="/kasutaja/isiku_objekt/:docId" component={ObjectDocument}/>
                <Route exact path="/kasutaja/objekt"
                       render={(props) => <ObjectRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/kasutaja/isiku_leping/:docId"
                       component={LepingDocument}/>
                <Route exact path="/kasutaja/leping"
                       render={(props) => <LepingRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/kasutaja/isiku_arv/:docId"
                       component={ArvDocument}/>
                <Route exact path="/kasutaja/arv/:docId"
                       component={ArvDocument}/>
                <Route exact path="/kasutaja/arv"
                       render={(props) => <ArvRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/kasutaja/smk/:docId"
                       component={SmkDocument}
                       module={MODULE}/>
                <Route exact path="/kasutaja/sorder/:docId"
                       component={SorderDocument}
                       module={MODULE}/>

                <Route exact path="/kasutaja/andmed/:docId"
                       component={MooduDocument}/>
                <Route exact path="/kasutaja/andmed"
                       render={(props) => <MooduRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
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