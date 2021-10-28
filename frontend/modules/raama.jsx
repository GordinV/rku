'use strict';

const React = require('react');
const PropTypes = require('prop-types');
const DocContext = require('./../doc-context.js');

const Menu = require('./../components/menu-toolbar/menu-toolbar.jsx');

const StartMenu = require('./../components/start-menu/start-menu.jsx'),
    RaamaRegister = require('./../docs/raama/index.jsx'),
    AsutusRegister = require('./../docs/asutused/index.jsx'),
    AsutusDocument = require('../docs/asutused/document/index.jsx'),
    ObjectDocument = require('../docs/objekt/document/index.jsx'),
    ObjectRegister = require('./../docs/objekt/index.jsx'),
    NomDocument = require('../docs/nomenclature/document/index.jsx'),
    NomRegister = require('./../docs/nomenclature/index.jsx'),
    LepingDocument = require('../docs/leping/document/index.jsx'),
    ArveRegister = require('./../docs/arv/index.jsx'),
    ArveDocument = require('../docs/arv/document/index.jsx'),
    SorderRegister = require('./../docs/sorder/index.jsx'),
    SorderDocument = require('../docs/sorder/document/index.jsx'),
    SmkRegister = require('./../docs/smk/index.jsx'),
    SmkDocument = require('../docs/smk/document/index.jsx'),
    VmkRegister = require('./../docs/vmk/index.jsx'),
    VmkDocument = require('../docs/vmk/document/index.jsx'),
    KaiveAruanne = require('./../docs/kaive_aruanne/index.jsx'),
    LepingRegister = require('./../docs/leping/index.jsx'),
    MooduDocument = require('../docs/moodu/document/index.jsx'),
    MooduRegister = require('./../docs/moodu/index.jsx');

const {Route} = require('react-router-dom');
const {StyleRoot} = require('radium');
const MODULE = 'raama';

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
                <Route exact path="/raama"
                       render={(props) =>
                           <RaamaRegister
                               history={props.history}
                               initData={this.props.initData}
                               module={MODULE}/>}/>
                <Route exact path="/raama/asutused/:docId" component={AsutusDocument}/>
                <Route exact path="/raama/asutused"
                       render={(props) => <AsutusRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}
                />
                <Route exact path="/raama/objekt/:docId" component={ObjectDocument}/>
                <Route exact path="/raama/objekt"
                       render={(props) => <ObjectRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/raama/arv/:docId"
                       component={ArveDocument}
                       module={MODULE}/>
                <Route exact path="/raama/arv"
                       render={(props) => <ArveRegister history={props.history}
                                                        initData={this.props.initData}
                                                        module={MODULE}/>}/>
                <Route exact path="/raama/sorder/:docId"
                       component={SorderDocument}
                       module={MODULE}/>
                <Route exact path="/raama/sorder"
                       render={(props) => <SorderRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/raama/smk/:docId"
                       component={SmkDocument}
                       module={MODULE}/>
                <Route exact path="/raama/smk"
                       render={(props) => <SmkRegister history={props.history}
                                                       initData={this.props.initData}
                                                       module={MODULE}/>}/>
                <Route exact path="/raama/vmk/:docId"
                       component={VmkDocument}
                       module={MODULE}/>
                <Route exact path="/raama/vmk"
                       render={(props) => <VmkRegister history={props.history}
                                                       initData={this.props.initData}
                                                       module={MODULE}/>}/>
                <Route exact path="/raama/leping/:docId"
                       component={LepingDocument}
                       module={MODULE}/>
                <Route exact path="/raama/leping"
                       render={(props) => <LepingRegister history={props.history}
                                                          initData={this.props.initData}
                                                          module={MODULE}/>}/>
                <Route exact path="/raama/andmed/:docId"
                       component={MooduDocument}
                       module={MODULE}/>
                <Route exact path="/raama/andmed"
                       render={(props) => <MooduRegister history={props.history}
                                                         initData={this.props.initData}
                                                         module={MODULE}/>}/>
                <Route exact path="/raama/nomenclature/:docId" component={NomDocument}/>
                <Route exact path="/raama/nomenclature"
                       render={(props) => <NomRegister history={props.history}
                                                       module={MODULE}
                                                       initData={this.props.initData}/>}/>
                <Route exact path="/raama/kaive_aruanne"
                       render={(props) => <KaiveAruanne history={props.history}
                                                        module={MODULE}
                                                        initData={this.props.initData}/>}/>
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