var admin=webpackJsonp_name_([0],{0:function(e,t,a){"use strict";function n(e){return e&&e.__esModule?e:{default:e}}var r=a(1),o=n(r),i=a(4),l=a(5),u=l.BrowserRouter,s=a(39);initData=JSON.parse(initData),userData=JSON.parse(userData),o.default.initData=initData,o.default.userData=userData,o.default.module="admin",o.default.pageName="Administraator",o.default.gridConfig=initData.docConfig,o.default.menu=initData.menu?initData.menu.data:[],o.default.keel="EST",i.hydrate(React.createElement(u,null,React.createElement(s,{initData:initData,userData:userData})),document.getElementById("doc"))},39:function(e,t,a){"use strict";function n(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=Object.assign||function(e){for(var t=1;t<arguments.length;t++){var a=arguments[t];for(var n in a)Object.prototype.hasOwnProperty.call(a,n)&&(e[n]=a[n])}return e},l=function(){function e(e,t){for(var a=0;a<t.length;a++){var n=t[a];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(e,n.key,n)}}return function(t,a,n){return a&&e(t.prototype,a),n&&e(t,n),t}}(),u=a(10),s=(a(11),a(1),a(40),a(81),a(169)),c=a(214),d=a(216),p=a(237),h=a(239),f=a(5),m=f.Route,y=a(87),b=y.StyleRoot,_="admin",g=function(e){function t(e){n(this,t);var a=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return a.prepareParamsForToolbar=a.prepareParamsForToolbar.bind(a),a}return o(t,e),l(t,[{key:"render",value:function(){var e=this;return u.createElement(b,null,u.createElement(m,{exact:!0,path:"/admin",render:function(t){return u.createElement(s,{history:t.history,initData:e.props.initData,module:_})}}),u.createElement(m,{exact:!0,path:"/admin/admin",render:function(t){return u.createElement(s,{history:t.history,initData:e.props.initData,module:_})}}),u.createElement(m,{exact:!0,path:"/admin/taotlus_login",render:function(t){return u.createElement(p,{history:t.history,initData:e.props.initData,module:_})}}),u.createElement(m,{exact:!0,path:"/admin/taotlus_login/:docId",render:function(e){return u.createElement(h,i({},e,{module:_,history:e.history}))}}),u.createElement(m,{exact:!0,path:"/admin/userid",render:function(t){return u.createElement(c,{history:t.history,initData:e.props.initData,module:_})}}),u.createElement(m,{exact:!0,path:"/admin/userid/:docId",render:function(e){return u.createElement(d,i({},e,{module:_,history:e.history}))}}))}},{key:"prepareParamsForToolbar",value:function(){return{btnStart:{show:!0},btnLogin:{show:!0,disabled:!1},btnAccount:{show:!0,disabled:!1}}}}]),t}(u.Component);e.exports=g},169:function(e,t,a){"use strict";function n(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var a=0;a<t.length;a++){var n=t[a];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(e,n.key,n)}}return function(t,a,n){return a&&e(t.prototype,a),n&&e(t,n),t}}(),l=a(10),u=a(170),s=a(213),c="ADMIN",d=a(85).TEATIS.toolbarProps,p=function(e){function t(e){n(this,t);var a=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return a.btnEditClick=a.btnEditClick.bind(a),a.renderer=a.renderer.bind(a),a.data=[],a}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(u,{initData:this.props.initData,history:this.props.history?this.props.history:null,module:this.props.module,ref:"register",docTypeId:c,style:s,btnEditClick:this.btnEditClick,toolbarProps:d,render:this.renderer})}},{key:"renderer",value:function(e){return e.gridData&&(this.data=e.gridData),null}},{key:"btnEditClick",value:function(e){var t=this.data.findIndex(function(t){return t.id=e});if(t>-1){var a=this.data[t].doc_type_id;return this.props.history.push({pathname:"/admin/"+a+"/"+e,state:{module:this.props.module}})}}}]),t}(l.PureComponent);e.exports=p},213:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},214:function(e,t,a){"use strict";function n(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var a=0;a<t.length;a++){var n=t[a];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(e,n.key,n)}}return function(t,a,n){return a&&e(t.prototype,a),n&&e(t,n),t}}(),l=a(10),u=a(170),s=a(215),c="USERID",d=function(e){function t(e){n(this,t);var a=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return a.render=a.render.bind(a),a}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(u,{initData:this.props.initData,history:this.props.history?this.props.history:null,module:this.props.module,ref:"register",docTypeId:c,style:s,render:this.renderer})}},{key:"renderer",value:function(){return null}}]),t}(l.PureComponent);e.exports=d},215:function(e,t){"use strict";e.exports={grid:{mainTable:{width:"100%",td:{border:"1px solid lightGrey",display:"table-cell",paddingLeft:"5px"}},headerTable:{width:"100%"},gridContainer:{width:"100%"}}}},216:function(e,t,a){"use strict";function n(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function r(e,t){if(!e)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!t||"object"!=typeof t&&"function"!=typeof t?e:t}function o(e,t){if("function"!=typeof t&&null!==t)throw new TypeError("Super expression must either be null or a function, not "+typeof t);e.prototype=Object.create(t&&t.prototype,{constructor:{value:e,enumerable:!1,writable:!0,configurable:!0}}),t&&(Object.setPrototypeOf?Object.setPrototypeOf(e,t):e.__proto__=t)}var i=function(){function e(e,t){for(var a=0;a<t.length;a++){var n=t[a];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(e,n.key,n)}}return function(t,a,n){return a&&e(t.prototype,a),n&&e(t,n),t}}(),l=a(10),u=a(11),s=a(217),c=a(206),d=a(210),p=a(181),h=a(236),f=function(e){function t(e){n(this,t);var a=r(this,(t.__proto__||Object.getPrototypeOf(t)).call(this,e));return a.state={docId:e.docId?e.docId:+e.match.params.docId,loadedData:!1},a.renderer=a.renderer.bind(a),a}return o(t,e),i(t,[{key:"render",value:function(){return l.createElement(s,{docId:this.state.docId,ref:"document",docTypeId:"USERID",module:this.props.module,initData:this.props.initData,renderer:this.renderer})}},{key:"renderer",value:function(e){return e.docData?l.createElement("div",{style:h.doc},l.createElement("div",{style:h.docRow},l.createElement("div",{style:h.docColumn},l.createElement(c,{title:"Kasutaja tunnus:  ",name:"kasutaja",ref:"input-kasutaja",readOnly:!0,value:e.docData.kasutaja||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Nimi: ",name:"ametnik",ref:"input-ametnik",readOnly:!e.state.edited,value:e.docData.ametnik||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Email: ",name:"email",ref:"input-email",readOnly:!e.state.edited,value:e.docData.email||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Smtp: ",name:"smtp",ref:"input-smtp",readOnly:!e.state.edited,value:e.docData.smtp||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Port: ",name:"port",ref:"input-port",readOnly:!e.state.edited,value:e.docData.port||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Email kasutaja: ",name:"user",ref:"input-user",readOnly:!e.state.edited,value:e.docData.user||"",onChange:e.handleInputChange}),l.createElement(c,{title:"Email parool: ",name:"pass",ref:"input-pass",readOnly:!e.state.edited,value:e.docData.pass||"",onChange:e.handleInputChange}),l.createElement(p,{title:"Kas raamatupidaja?",name:"is_kasutaja",value:!!e.docData.is_kasutaja,ref:"checkbox_is_kasutaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas peakasutaja?",name:"is_peakasutaja",value:!!e.docData.is_peakasutaja,ref:"checkbox_is_peakasutaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas administraator?",name:"is_admin",value:!!e.docData.is_admin,ref:"checkbox_is_admin",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas vaatleja?",name:"is_vaatleja",value:!!e.docData.is_vaatleja,ref:"checkbox_is_vaatleja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas laste arvestaja?",name:"is_arvestaja",value:!!e.docData.is_arvestaja,ref:"checkbox_is_arvestaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas eelarve taotluse koostaja?",name:"is_eel_koostaja",value:!!e.docData.is_eel_koostaja,ref:"checkbox_is_eel_koostaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas eelarve taotluse allkriastaja?",name:"is_eel_allkirjastaja",value:!!e.docData.is_eel_allkirjastaja,ref:"checkbox_is_eel_allkirjastaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas eelarve taotluse esitaja?",name:"is_eel_esitaja",value:!!e.docData.is_eel_esitaja,ref:"checkbox_is_eel_esitaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas asutuste korraldaja?",name:"is_asutuste_korraldaja",value:!!e.docData.is_asutuste_korraldaja,ref:"checkbox_is_asutuste_korraldaja",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas rekl.maksu administraator?",name:"is_rekl_administrator",value:!!e.docData.is_rekl_administrator,ref:"checkbox_is_rekl_administrator",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas rekl.maksu haldur?",name:"is_rekl_maksuhaldur",value:!!e.docData.is_rekl_maksuhaldur,ref:"checkbox_is_rekl_maksuhaldur",onChange:e.handleInputChange,readOnly:!0}),l.createElement(p,{title:"Kas ladu kasutaja?",name:"is_ladu_kasutaja",value:!!e.docData.is_ladu_kasutaja,ref:"checkbox_is_ladu_kasutaja",onChange:e.handleInputChange,readOnly:!0}))),l.createElement("div",{style:h.docRow},l.createElement(d,{title:"Muud",name:"muud",ref:"textarea-muud",onChange:e.handleInputChange,value:e.docData.muud||"",readOnly:!e.state.edited}))):null}}]),t}(l.PureComponent);f.propTypes={docId:u.number,initData:u.object},f.defaultProps={initData:{}},e.exports=f},236:function(e,t){"use strict";e.exports={docRow:{display:"flex",flexDirection:"row"},docColumn:{display:"flex",flexDirection:"column",width:"50%"},doc:{display:"flex",flexDirection:"column"}}}});