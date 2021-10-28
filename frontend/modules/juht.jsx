'use strict';

const React = require('react');
const PropTypes = require('prop-types');
const DocContext = require('./../doc-context.js');

const Menu = require('./../components/menu-toolbar/menu-toolbar.jsx');

const StartMenu = require('./../components/start-menu/start-menu.jsx'),
    JuhtRegister = require('./../docs/juht/index.jsx'),
    NomDocument = require('../docs/nomenclature/document/index.jsx'),
    NomRegister = require('./../docs/nomenclature/index.jsx'),
    ObjectDocument = require('../docs/objekt/document/index.jsx'),
    ObjectRegister = require('./../docs/objekt/index.jsx'),
    LepingDocument = require('../docs/leping/document/index.jsx'),
    LepingRegister = require('./../docs/leping/index.jsx'),
    ArvDocument = require('../docs/arv/document/index.jsx'),
    ArvRegister = require('./../docs/arv/index.jsx'),
    AsutusRegister = require('./../docs/asutused/index.jsx'),
    AsutusDocument = require('../docs/asutused/document/index.jsx'),
    TaotlusLoginRegister = require('./../docs/taotlus_login/index.jsx'),
    TaotlusLoginDocument = require('./../docs/taotlus_login/document/index.jsx'),
    RekvDocument = require('../docs/rekv/document/index.jsx'),
    ReklDocument = require('../docs/rekl/document/index.jsx'),
    ReklRegister = require('./../docs/rekl/index.jsx'),
    MooduDocument = require('../docs/moodu/document/index.jsx'),
    MooduRegister = require('./../docs/moodu/index.jsx');


const {Route} = require('react-router-dom');
const {StyleRoot} = require('radium');
const MODULE = 'juht';

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
        let activeStyle = {backgroundColor: 'lightblue'};
        let btnParams = this.prepareParamsForToolbar();

        return (
            <StyleRoot>
                <Route exact path="/juht"
                       render={(props) =>
                           <JuhtRegister
                               history={props.history}
                               initData={this.props.initData}
                               module={MODULE}/>}/>
                <Route exact path="/juht/juht"
                       render={(props) => <JuhtRegister history={props.history}
                                                        initData={this.props.initData}
                                                        module={MODULE}/>}
                />
                <Route exact path="/juht/taotlus_login"
                       render={(props) => <TaotlusLoginRegister history={props.history}
                                                                initData={this.props.initData}
                                                                module={MODULE}/>}
                />
                <Route exact path="/juht/taotlus_login/:docId"
                       render={(props) => <TaotlusLoginDocument  {...props}
                                                                 module={MODULE}
                                                                 history={props.history}/>}
                />
                <Route exact path="/juht/objekt/:docId" component={ObjectDocument}/>
                <Route exact path="/juht/objekt"
                       render={(props) => <ObjectRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/juht/leping/:docId"
                       component={LepingDocument}/>
                <Route exact path="/juht/leping"
                       render={(props) => <LepingRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/juht/rekv/:docId"
                       component={RekvDocument}/>
                <Route exact path="/juht/rekl/:docId"
                       component={ReklDocument}/>
                <Route exact path="/juht/rekl"
                       render={(props) => <ReklRegister history={props.history}
                                                        initData={this.props.initData}
                                                        module={MODULE}/>}/>
                <Route exact path="/juht/andmed/:docId"
                       component={MooduDocument}
                       module={MODULE}/>
                <Route exact path="/juht/andmed"
                       render={(props) => <MooduRegister history={props.history}
                                                         initData={this.props.initData}
                                                         module={MODULE}/>}/>
                <Route exact path="/juht/asutused/:docId" component={AsutusDocument}/>
                <Route exact path="/juht/asutused"
                       render={(props) => <AsutusRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/juht/nomenclature/:docId" component={NomDocument}/>
                <Route exact path="/juht/nomenclature"
                       render={(props) => <NomRegister history={props.history}
                                                       module={MODULE}
                                                       initData={this.props.initData}/>}/>
                <Route exact path="/juht/arv/:docId"
                       component={ArvDocument}/>
                <Route exact path="/juht/arv"
                       render={(props) => <ArvRegister history={props.history}
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