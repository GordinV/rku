var juht=webpackJsonp_name_([1],{0:function(e,t,n){"use strict";function a(e){return e&&e.__esModule?e:{default:e}}var r=n(1),o=a(r),i=n(4),l=n(5),d=l.BrowserRouter,u=n(247);initData=JSON.parse(initData),userData=JSON.parse(userData),o.default.initData=initData,o.default.userData=userData,o.default.module="juht",o.default.pageName="Juhataja",o.default.gridConfig=initData.docConfig,o.default.menu=initData.menu?initData.menu.data:[],o.default.keel="EST",i.hydrate(React.createElement(d,null,React.createElement(u,{initData:initData,userData:userData})),document.getElementById("doc"))},241:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(11),u=n(217),c=n(206),s=n(174),p=n(210),h=n(178),f=n(163),m=n(181),y=n(242),b=n(85).REKV.LIB_OBJS,v=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.state={docId:e.docId?e.docId:+e.match.params.docId,loadedData:!1},n.renderer=n.renderer.bind(n),n.createGridRow=n.createGridRow.bind(n),n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(u,{docId:this.state.docId,ref:"document",docTypeId:"REKV",history:this.props.history,module:this.props.module,libs:b,initData:this.props.initData,renderer:this.renderer,createGridRow:this.createGridRow})}},{key:"renderer",value:function(e){if(!e.docData)return null;var t=e.docData.gridData,n=e.docData.gridConfig;return l.createElement("div",{style:y.doc},l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Regkood: ",name:"regkood",ref:"input-regkood",readOnly:!e.state.edited,value:e.docData.regkood||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"KBM kood: ",name:"kbmkood",ref:"input-kbmkood",readOnly:!e.state.edited,value:e.docData.kbmkood||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Nimetus: ",name:"nimetus",ref:"input-nimetus",readOnly:!e.state.edited,value:e.docData.nimetus||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Täis. nimetus: ",name:"muud",ref:"input-muud",readOnly:!e.state.edited,value:e.docData.muud||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(f,{title:"Asutuse liik:",name:"liik",data:e.libs.asutuse_liik,value:e.docData.liik||"",defaultValue:e.docData.liik||"",ref:"liik",collId:"kood",readOnly:!e.state.edited,onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(p,{title:"Aadress: ",name:"aadress",ref:"textarea-aadress",onChange:e.handleInputChange,value:e.docData.aadress||"",readOnly:!e.state.edited})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Juhataja: ",name:"juht",ref:"input-juht",readOnly:!e.state.edited,value:e.docData.juht||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Raamatupidaja: ",name:"raama",ref:"input-raama",readOnly:!e.state.edited,value:e.docData.raama||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Email: ",name:"email",ref:"input-email",readOnly:!e.state.edited,value:e.docData.email||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Omniva salasõna: ",name:"earved",ref:"input-earved",readOnly:!e.state.edited,value:e.docData.earved||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"E-arve asutuse reg.kood: ",name:"earve_regkood",ref:"input-earve_regkood",readOnly:!e.state.edited,value:e.docData.earve_regkood||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docRow},l.createElement("div",{style:y.docColumn},l.createElement(c,{title:"SEB e-arve aa: ",name:"seb_earve",ref:"input-seb_earve",readOnly:!e.state.edited,value:e.docData.seb_earve||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docColumn},l.createElement(c,{title:"SEB kasutaja tunnus: ",name:"seb",ref:"input-seb_parool",readOnly:!e.state.edited,value:e.docData.seb||"",onChange:e.handleInputChange}))),l.createElement("div",{style:y.docRow},l.createElement("div",{style:y.docColumn},l.createElement(c,{title:"SWED e-arve aa: ",name:"swed_earve",ref:"input-swed-earve",readOnly:!e.state.edited,value:e.docData.swed_earve||"",onChange:e.handleInputChange})),l.createElement("div",{style:y.docColumn},l.createElement(c,{title:"SWED kasutaja tunnus: ",name:"swed",ref:"input-swed_parool",readOnly:!e.state.edited,value:e.docData.swed||"",onChange:e.handleInputChange}))),l.createElement("div",{style:y.docRow},l.createElement(s,{source:"details",gridData:t,gridColumns:n,showToolBar:e.state.edited,handleGridRow:this.handleGridRow,handleGridBtnClick:e.handleGridBtnClick,readOnly:!e.state.edited,style:y.grid.headerTable,ref:"data-grid"})),e.state.gridRowEdit?this.createGridRow(e):null)}},{key:"createGridRow",value:function(e){var t=e.gridRowData?e.gridRowData:{},n="",a=n.length>0||!e.state.checked,r=["btnOk","btnCancel"];return a&&r.splice(0,1),t?l.createElement("div",{className:".modalPage"},l.createElement(h,{modalObjects:r,ref:"modalpage-grid-row",show:!0,modalPageBtnClick:e.modalPageClick,modalPageName:"Rea lisamine / parandamine"},l.createElement("div",{ref:"grid-row-container"},e.state.gridWarning.length?l.createElement("div",{style:y.docRow},l.createElement("span",null,e.state.gridWarning)):null,l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Number: ",name:"arve",value:t.arve||"",readOnly:!1,disabled:!1,bindData:!1,ref:"number",onChange:e.handleGridRowInput})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Nimetus: ",name:"nimetus",value:t.nimetus||"",readOnly:!1,disabled:!1,bindData:!1,ref:"number",onChange:e.handleGridRowInput})),l.createElement("div",{style:y.docRow},l.createElement(f,{title:"Tüüp: ",name:"kassapank",data:[{id:0,nimetus:"Kassa"},{id:1,nimetus:"Pank"},{id:2,nimetus:"TP"}],value:t.kassapank||"",ref:"kassapank",collId:"id",onChange:e.handleGridRowChange})),l.createElement("div",{style:y.docRow},l.createElement(f,{title:"Konto: ",name:"konto",data:e.libs.kontod,value:t.konto||"",ref:"konto",collId:"kood",onChange:e.handleGridRowChange})),l.createElement("div",{style:y.docRow},l.createElement(m,{title:"Kas põhiline?",name:"default_",value:!!e.docData.default_,ref:"checkbox_default_",onChange:e.handleInputChange,readOnly:!1}))),l.createElement("div",null,l.createElement("span",null,n)))):l.createElement("div",null)}}]),t}(l.PureComponent);v.propTypes={docId:d.number,initData:d.object},v.defaultProps={initData:{}},e.exports=v},242:function(e,t){"use strict";e.exports={docRow:{display:"flex",flexDirection:"row"},docColumn:{display:"flex",flexDirection:"column",width:"50%"},doc:{display:"flex",flexDirection:"column"},grid:{mainTable:{width:"100%"},headerTable:{width:"100%"},gridContainer:{width:"100%"}},gridRow:{backgroundColor:"white",position:"relative",margin:"10% 30% 10% 30%",width:"auto",opacity:"1",top:"100px"},btnEdit:{width:"min-content"}}},247:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=Object.assign||function(e){for(var t=1;t<arguments.length;t++){var n=arguments[t];for(var a in n)Object.prototype.hasOwnProperty.call(n,a)&&(e[a]=n[a])}return e},l=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),d=n(10),u=(n(11),n(1),n(40),n(81),n(248)),c=n(250),s=n(252),p=n(254),h=n(256),f=n(258),m=n(264),y=n(267),b=n(269),v=n(274),g=n(276),E=n(243),w=n(245),C=n(241),D=n(278),k=n(280),O=n(282),j=n(284),_=n(5),I=_.Route,x=n(87),R=x.StyleRoot,T="juht",P=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.prepareParamsForToolbar=n.prepareParamsForToolbar.bind(n),n}return o(t,e),l(t,[{key:"render",value:function(){var e=this;this.prepareParamsForToolbar();return d.createElement(R,null,d.createElement(I,{exact:!0,path:"/juht",render:function(t){return d.createElement(u,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/juht",render:function(t){return d.createElement(u,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/taotlus_login",render:function(t){return d.createElement(E,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/taotlus_login/:docId",render:function(e){return d.createElement(w,i({},e,{module:T,history:e.history}))}}),d.createElement(I,{exact:!0,path:"/juht/objekt/:docId",component:p}),d.createElement(I,{exact:!0,path:"/juht/objekt",render:function(t){return d.createElement(h,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/leping/:docId",component:f}),d.createElement(I,{exact:!0,path:"/juht/leping",render:function(t){return d.createElement(m,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/rekv/:docId",component:C}),d.createElement(I,{exact:!0,path:"/juht/rekl/:docId",component:D}),d.createElement(I,{exact:!0,path:"/juht/rekl",render:function(t){return d.createElement(k,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/andmed/:docId",component:O,module:T}),d.createElement(I,{exact:!0,path:"/juht/andmed",render:function(t){return d.createElement(j,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/asutused/:docId",component:g}),d.createElement(I,{exact:!0,path:"/juht/asutused",render:function(t){return d.createElement(v,{history:t.history,initData:e.props.initData,module:T})}}),d.createElement(I,{exact:!0,path:"/juht/nomenclature/:docId",component:c}),d.createElement(I,{exact:!0,path:"/juht/nomenclature",render:function(t){return d.createElement(s,{history:t.history,module:T,initData:e.props.initData})}}),d.createElement(I,{exact:!0,path:"/juht/arv/:docId",component:y}),d.createElement(I,{exact:!0,path:"/juht/arv",render:function(t){return d.createElement(b,{history:t.history,initData:e.props.initData,module:T})}}))}},{key:"prepareParamsForToolbar",value:function(){return{btnStart:{show:!0},btnLogin:{show:!0,disabled:!1},btnAccount:{show:!0,disabled:!1}}}}]),t}(d.Component);e.exports=P},248:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(170),u=n(249),c="JUHT",s=n(85).TEATIS.toolbarProps,p=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.btnEditClick=n.btnEditClick.bind(n),n.renderer=n.renderer.bind(n),n.data=[],n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(d,{initData:this.props.initData,history:this.props.history?this.props.history:null,module:this.props.module,ref:"register",docTypeId:c,style:u,btnEditClick:this.btnEditClick,toolbarProps:s,render:this.renderer})}},{key:"renderer",value:function(e){return e.gridData&&(this.data=e.gridData),null}},{key:"btnEditClick",value:function(e){var t=this.data.findIndex(function(t){return t.id=e});if(t>-1){var n=this.data[t].doc_type_id;return this.props.history.push({pathname:"/"+this.props.module+"/"+n+"/"+e,state:{module:this.props.module}})}}}]),t}(l.PureComponent);e.exports=p},249:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},250:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(11),u=n(217),c=n(206),s=n(230),p=n(163),h=n(210),f=n(232),m=n(251),y=n(85).NOMENCLATURE,b=y.LIBRARIES,v=y.TAXIES,g=y.UHIK,E=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.state={docId:e.docId?e.docId:+e.match.params.docId,loadedData:!1},n.renderer=n.renderer.bind(n),n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(u,{docId:this.state.docId,ref:"document",docTypeId:"NOMENCLATURE",module:this.props.module,initData:this.props.initData,history:this.props.history,userData:this.props.userData,libs:b,renderer:this.renderer,focusElement:"input-kood"})}},{key:"renderer",value:function(e){if(!e.docData)return null;var t=e.state.edited;return l.createElement("div",null,l.createElement("div",{style:m.doc},l.createElement("div",{style:m.docRow},l.createElement("div",{style:m.docColumn},l.createElement(c,{title:"Kood ",name:"kood",ref:"input-kood",value:e.docData.kood,onChange:e.handleInputChange}),l.createElement(c,{title:"Nimetus ",name:"nimetus",ref:"input-nimetus",value:e.docData.nimetus,onChange:e.handleInputChange}),l.createElement(p,{title:"Maksumäär:",name:"vat",data:v,collId:"kood",value:e.docData.vat||"",defaultValue:e.docData.vat,ref:"select-vat",btnDelete:t,onChange:e.handleInputChange,readOnly:!t}),l.createElement(f,{title:"Hind: ",name:"hind",ref:"input-hind",value:+(e.docData.hind||null),readOnly:!t,onChange:e.handleInputChange}),l.createElement(p,{title:"Mõttühik:",name:"uhik",data:g,collId:"kood",value:e.docData.uhik||"",defaultValue:e.docData.uhik,ref:"select-uhik",btnDelete:t,onChange:e.handleInputChange,readOnly:!t}))),l.createElement("div",{style:m.docRow},l.createElement("div",{style:m.docColumn},l.createElement(s,{title:"Kehtiv kuni:",name:"valid",value:e.docData.valid,ref:"input-valid",readOnly:!t,onChange:e.handleInputChange}))),l.createElement("div",{style:m.docRow},l.createElement(h,{title:"Muud",name:"muud",ref:"textarea-muud",onChange:e.handleInputChange,value:e.docData.muud||"",readOnly:!t}))))}}]),t}(l.PureComponent);E.propTypes={docId:d.number,initData:d.object,userData:d.object},E.defaultProps={initData:{},userData:{}},e.exports=E},251:function(e,t){"use strict";e.exports={docRow:{display:"flex",flexDirection:"row"},docColumn:{display:"flex",flexDirection:"column",width:"50%"},doc:{display:"flex",flexDirection:"column"}}},252:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(170),u=n(253),c="NOMENCLATURE",s=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.renderer=n.renderer.bind(n),n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(d,{initData:this.props.initData,history:this.props.history?this.props.history:null,ref:"register",module:this.props.module,docTypeId:c,style:u,render:this.renderer})}},{key:"renderer",value:function(){return null}}]),t}(l.PureComponent);e.exports=s},253:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},274:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(170),u=n(275),c="ASUTUSED",s=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.handleClick=n.handleClick.bind(n),n.renderer=n.renderer.bind(n),n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(d,{history:this.props.history?this.props.history:null,module:this.props.module,ref:"register",docTypeId:c,style:u,render:this.renderer})}},{key:"renderer",value:function(){return null}},{key:"handleClick",value:function(e){var t=this.refs.register;return t?void(e&&(t.setState({warning:"Edukalt:  "+e+": ",warningType:"ok"}),setTimeout(function(){t.fetchData("selectDocs")},1e4))):null}}]),t}(l.PureComponent);e.exports=s},275:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},276:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(11),u=n(1),c=n(217),s=n(206),p=n(210),h=n(277),f=n(174),m=n(237),y=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.state={docId:e.docId?e.docId:+e.match.params.docId,loadedData:!1},n.renderer=n.renderer.bind(n),n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(c,{docId:this.state.docId,ref:"document",history:this.props.history,module:u.module,docTypeId:"ASUTUSED",initData:this.props.initData,renderer:this.renderer,focusElement:"input-regkood"})}},{key:"renderer",value:function(e){if(!e.docData||!e.docData.nimetus)return l.createElement("div",{style:h.doc},l.createElement(m,{label:"Laadimine..."}));var t=e.state.edited,n=e.docData.gridData,a=e.docData.gridConfig,r=e.docData.objects,o=e.docData.gridObjectsConfig;return l.createElement("div",{style:h.doc},l.createElement("div",{style:h.docRow},l.createElement("div",{style:h.docColumn},l.createElement(s,{title:"Reg.kood ",name:"regkood",ref:"input-regkood",readOnly:!t,value:e.docData.regkood||"",onChange:e.handleInputChange}),l.createElement(s,{title:"Nimetus ",name:"nimetus",ref:"input-nimetus",readOnly:!t,value:e.docData.nimetus||"",onChange:e.handleInputChange}),l.createElement(s,{title:"Om.vorm",name:"omvorm",ref:"input-omvorm",readOnly:!t,value:e.docData.omvorm||"",onChange:e.handleInputChange}),l.createElement(s,{title:"Arveldus arve:",name:"aa",ref:"input-aa",readOnly:!t,value:e.docData.aa||"",onChange:e.handleInputChange}))),l.createElement("div",{style:h.docRow},l.createElement(p,{title:"Aadress",name:"aadress",ref:"textarea-aadress",onChange:e.handleInputChange,value:e.docData.aadress||"",readOnly:!t})),l.createElement("div",{style:h.docRow},l.createElement(p,{title:"Kontakt",name:"kontakt",ref:"textarea-kontakt",onChange:e.handleInputChange,value:e.docData.kontakt||"",readOnly:!t})),l.createElement("div",{style:h.docRow},l.createElement(s,{title:"Telefon",name:"tel",ref:"input-tel",value:e.docData.tel||"",readOnly:!t,onChange:e.handleInputChange})),l.createElement("div",{style:h.docRow},l.createElement(s,{title:"Email",name:"email",ref:"input-email",value:e.docData.email||"",readOnly:!t,onChange:e.handleInputChange})),l.createElement("div",{style:h.docRow},l.createElement(p,{title:"Muud",name:"muud",ref:"textarea-muud",onChange:e.handleInputChange,value:e.docData.muud||"",readOnly:!t})),l.createElement("div",{style:h.docRow},l.createElement(p,{title:"Märkused",name:"mark",ref:"textarea-mark",onChange:e.handleInputChange,value:e.docData.mark||"",readOnly:!t})),l.createElement("div",{style:h.docRow},l.createElement("label",{ref:"label"},"Kasutaja objektid")),l.createElement("div",{style:h.docRow},l.createElement(f,{source:"objects",gridData:r,gridColumns:o,showToolBar:!1,readOnly:!0,style:h.grid.headerTable,docTypeId:"object",ref:"objects-data-grid"})),l.createElement("div",{style:h.docRow},l.createElement("label",{ref:"label"},"Kasutaja andmed")),l.createElement("div",{style:h.docRow},l.createElement(f,{source:"userid",gridData:n,gridColumns:a,showToolBar:!1,readOnly:!0,style:h.grid.headerTable,docTypeId:"userid",ref:"userid-data-grid"})))}}]),t}(l.PureComponent);y.propTypes={docId:d.number,initData:d.object,userData:d.object},y.defaultProps={initData:{},userData:{}},e.exports=y},277:function(e,t){"use strict";e.exports={docRow:{display:"flex",flexDirection:"row"},docColumn:{display:"flex",flexDirection:"column",width:"50%"},doc:{display:"flex",flexDirection:"column"},grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},278:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(11),u=n(217),c=n(210),s=n(230),p=n(163),h=n(237),f=n(79),m=n(85).REKL.LIB_OBJS,y=n(279),b=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.state={docId:e.docId?e.docId:+e.match.params.docId,loadedData:!1},n.renderer=n.renderer.bind(n),n.btnCheckLinkClick=n.btnCheckLinkClick.bind(n),n.link="",n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(u,{docId:this.state.docId,ref:"document",docTypeId:"REKL",libs:m,module:this.props.module,initData:this.props.initData,userData:this.props.userData,renderer:this.renderer,focusElement:"input-alg_kpv",history:this.props.history})}},{key:"renderer",value:function(e){return e.docData?(this.link=e.docData.link,l.createElement("div",{style:y.doc},l.createElement("div",{style:y.docRow},l.createElement("div",{style:y.docColumn},l.createElement(s,{title:"Alg. Kuupäev ",name:"alg_kpv",value:e.docData.alg_kpv,ref:"input-alg_kpv",readOnly:!e.state.edited,onChange:e.handleInputChange}),l.createElement(s,{title:"Lõpp kuupäev ",name:"lopp_kpv",value:e.docData.lopp_kpv,ref:"input-lopp_kpv",readOnly:!e.state.edited,onChange:e.handleInputChange}),l.createElement(p,{title:"Reklaamiandja:",libs:"asutused",name:"asutusid",data:e.libs.asutused,value:e.docData.asutusid||0,defaultValue:e.docData.asutus,onChange:e.handleInputChange,collId:"id",readOnly:!e.state.edited}))),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Nimetus",name:"nimetus",ref:"textarea-nimetus",onChange:e.handleInputChange,value:e.docData.nimetus||"",readOnly:!e.state.edited})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Link",name:"link",ref:"textarea-link",onChange:e.handleInputChange,value:e.docData.link||"",readOnly:!e.state.edited})),l.createElement("div",{style:y.docRow},l.createElement(f,{ref:"btnEdit",value:"Kontrolli link",onClick:this.btnCheckLinkClick,show:!e.state.edited,style:y.btnEdit,disabled:!1})),l.createElement("div",{style:y.docRow},l.createElement(c,{title:"Muud",name:"muud",ref:"textarea-muud",onChange:e.handleInputChange,value:e.docData.muud||"",readOnly:!e.state.edited})))):l.createElement("div",{style:y.doc},l.createElement(h,{label:"Laadimine..."}))}},{key:"btnCheckLinkClick",value:function(){window.open(this.link,"_blank")}}]),t}(l.PureComponent);b.propTypes={docId:d.number,initData:d.object},b.defaultProps={initData:{}},e.exports=b},279:function(e,t){"use strict";e.exports={docRow:{display:"flex",flexDirection:"row"},docColumn:{display:"flex",flexDirection:"column",width:"50%"},doc:{display:"flex",flexDirection:"column"},grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},280:function(e,t,n){"use strict";function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var n=0;n<t.length;n++){var a=t[n];a.enumerable=a.enumerable||!1,a.configurable=!0,"value"in a&&(a.writable=!0),Object.defineProperty(e,a.key,a)}}return function(t,n,a){return n&&e(t.prototype,n),a&&e(t,a),t}}(),l=n(10),d=n(170),u=n(281),c="REKL",s=function(e){function t(e){a(this,t);var n=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return n.renderer=n.renderer.bind(n),n.data=[],n}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(d,{initData:this.props.initData,history:this.props.history?this.props.history:null,module:this.props.module,ref:"register",docTypeId:c,style:u,render:this.renderer})}},{key:"renderer",value:function(e){return null}}]),t}(l.PureComponent);e.exports=s},281:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}}});