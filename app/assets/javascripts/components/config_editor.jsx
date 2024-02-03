"use strict";

/*
Notes:
- Can't use Array.includes(...). It's not supported in Edge 13, which is shipped with Windows 10 by default.

TODO:

- malformed input
- fix FIXMEs
*/


class Conditional extends React.Component {
  constructor(props) {
    super(props);
    if (props.name) {
      this.props.db.setHidden(props.name, !props.condition);
    } else if (props.names) {
      for (let name of props.names) {
        this.props.db.setHidden(name, !props.condition);
      }
    }
    // If it doesn't have a name, it's probably because it's a localized text,
    // which we haven't supported conditional removal yet.
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.condition != this.props.condition) {
      if (this.props.name) {
        this.props.db.setHidden(this.props.name, !nextProps.condition);
      } else if (this.props.names) {
        for (let name of this.props.names) {
          this.props.db.setHidden(name, !nextProps.condition);
        }
      }
    }
  }

  render() {
    return (
      this.props.condition ? this.props.children : null
    );
  }
}

class BooleanOption extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
  }

  handleChange(event) {
    const checked = event.target.checked;
    this.props.db.set(this.props.name, checked);
  }

  render() {
    return (
      <div className="form-check">
        <input type="checkbox" className="form-check-input" checked={this.props.db.get(this.props.name)} onChange={this.handleChange} id={this.props.name} />
        <label className="form-check-label" htmlFor={this.props.name}>{this.props.label}</label>
      </div>
    );
  }
}

class CheckboxOption extends React.Component {
  handleChange(event, k) {
    const values = this.props.db.get(this.props.name).slice(0);
    if (event.target.checked) {
      values.push(k);
      // A way to make available locales sorted.
      const allValues = this.props.values.map(x => x[0]);
      values.sort((x, y) => (allValues.indexOf(x) - allValues.indexOf(y)));
    } else {
      values.splice(values.indexOf(k), 1);
    }
    this.props.db.set(this.props.name, values);
  }

  render() {
    const values = this.props.db.get(this.props.name);
    return (
      this.props.values.map(value => {
        const k = value[0];
        return (
          <div key={k} className="form-check">
            <input type="checkbox" className="form-check-input" checked={values.indexOf(k) != -1} onChange={e => { this.handleChange(e, k); }} id={this.props.name + "_" + k} />
            <label className="form-check-label" htmlFor={this.props.name + "_" + k}>{value[1]}</label>
          </div>
        );
      })
    );
  }
}

/*
class RadioOption extends React.Component {
  handleChange(event, k) {
    this.props.db.set(this.props.name, k);
  }

  render() {
    const value = this.props.db.get(this.props.name);
    return (
      this.props.values.map(x => {
        const k = x[0];
        return (
          <div key={k} className="radio">
            <label><input type="radio" checked={value == k} onChange={e => { this.handleChange(e, k); }} /> {x[1]}</label>
          </div>
        );
      })
    );
  }
}
*/

class SelectOption extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
  }

  handleChange(event) {
    // Can't just use event.target.value because it's converted to a string.
    const i = +event.target.value;
    this.props.db.set(this.props.name, this.props.values[i][0]);
  }

  render() {
    const value = this.props.db.get(this.props.name);
    const values = this.props.values;
    const selectedIndex = values.map(x => x[0]).indexOf(value);
    return (
      <select className="form-control" value={selectedIndex} onChange={this.handleChange}>
        {values.map((x, i) => (
          <option key={x[0]} value={i}>{x[1]}</option>
        ))}
      </select>
    );
  }
}

// A better number field. Some browsers (such as Safari) allow users to enter
// any text into <input type="number" /> fields. This can cause some confusion.
// Also, this class will always call onChange() with a number.
class NumberInput extends React.Component {
  constructor(props) {
    super(props);
    // FIXME: Should only allow integers.

    this.state = {
      isEditing: false,
      text: ""
    };
    this.handleInputChange = this.handleInputChange.bind(this);
    this.handleFocus = this.handleFocus.bind(this);
    this.handleBlur = this.handleBlur.bind(this);
  }

  handleInputChange(event) {
    const text = event.target.value;
    this.setState({text: text});

    const value = +text;
    if (isNaN(value)) {
      // This never happens, as modern browsers (including Safari) won't trigger
      // the change event if the text is not convertible to a number.
      // This conforms to the HTML5 spec.
      //this.props.onChange(text);
    } else {
      const multiplier = (this.props.multiplier !== undefined) ? this.props.multiplier : 1;
      this.props.onChange(value * multiplier);
    }
  }

  handleFocus() {
    this.setState({ isEditing: true, text: this.stringValue() });
  }

  handleBlur() {
    this.setState({ isEditing: false });
  }

  stringValue() {
    if (this.props.value == 0 && this.props.showEmptyStringForZero)
      return "";
    const multiplier = (this.props.multiplier !== undefined) ? this.props.multiplier : 1;
    return String(this.props.value / multiplier);
  }

  render() {
    const value = this.state.isEditing ? this.state.text : this.stringValue();
    return (
      <input type="number" className={this.props.className} onChange={this.handleInputChange} value={value} onFocus={this.handleFocus} onBlur={this.handleBlur} />
    );
  }
}

class NumberOption extends React.Component {
  render() {
    const input = (<NumberInput className="form-control" onChange={value => { this.props.db.set(this.props.name, value); }} value={this.props.db.get(this.props.name)} multiplier={this.props.multiplier} showEmptyStringForZero={this.props.showEmptyStringForZero} />);
    return (
      this.props.appendText === undefined ? (
        input
      ) : (
        <div className="input-group">
          {input}
          <div className="input-group-append"><div className="input-group-text">{this.props.appendText}</div></div>
        </div>
      )
    );
  }
}

class TextOption extends React.Component {
  render() {
    return (
      <input type="text" className="form-control" onChange={event => { this.props.db.set(this.props.name, event.target.value); }} value={this.props.db.get(this.props.name)} placeholder={this.props.placeholder} dir={this.props.dir} />
    );
  }
}

class TinyMCEEditor extends React.Component {
  constructor(props) {
    super(props);
    this.value = props.value;
  }

  componentDidMount() {
    tinymce.init({
      target: this.node,
      branding: false,
      elementpath: false,
      //statusbar: false,
      menubar: false,
      directionality: (this.props.dir == "rtl") ? "rtl" : "ltr",

      // https://www.tinymce.com/docs/advanced/editor-control-identifiers/#toolbarcontrols
      // styleselect formatselect
      toolbar: "fontsizeselect | bold italic underline forecolor | link image | alignleft aligncenter | bullist numlist | code",
      height: 120,

      plugins: ["link", "code", "lists", "textcolor", "image"],
      link_title: false,
      fontsize_formats: "14px 16px 18px 20px 24px 36px 48px",
      inline: true,
      init_instance_callback: (editor) => {
        this.editor = editor;
        const update = (e) => {
          const value = editor.getContent();
          this.value = value;
          this.props.onChange(value);
        }
        editor.on('Change', update); // Necessary?
        editor.on('Blur', update);
      },
      //theme: 'mobile',
    });
  }

  componentWillUnmount() {
    if (this.editor) {
      this.editor.remove();
    }
  }

  componentWillReceiveProps(nextProps) {
    const value = nextProps.value;
    if (this.value != value) {
      this.value = value;
      if (this.editor) {
        this.editor.setContent(value);
      }
    }
  }

  shouldComponentUpdate(nextProps) {
    return false;
  }

  render() {
    return (
      <div ref={node => this.node = node} className="tinyMCEEditor" dangerouslySetInnerHTML={{__html: this.props.value}} />
    );
  }
}

class HTMLOption extends React.Component {
  render() {
    /*
    return (
      <textarea rows={4} className="form-control" onChange={event => { this.props.db.set(this.props.name, event.target.value); }} value={this.props.db.get(this.props.name)} />
    );
    */
    return (
      <TinyMCEEditor onChange={value => { this.props.db.set(this.props.name, value); }} value={this.props.db.get(this.props.name)} dir={this.props.dir} />
    );
  }
}

class LocalizedTextOption extends React.Component {
  constructor(props) {
    super(props);
    this.handleReset = this.handleReset.bind(this);
  }

  handleReset(event) {
    event.preventDefault();
    if (confirm("Are you sure you want to reset the text to the default text?")) {
      const db = this.props.db;
      const locales = db.get("available_locales");
      for (let locale of locales) {
        db.set("locales." + locale + "." + this.props.name, undefined);
      }
    }
  }

  render() {
    const locales = this.props.db.get("available_locales");
    const showReset = this.props.showReset === undefined || this.props.showReset;
    const isHTML = this.props.isHTML === undefined || this.props.isHTML;
    const Option = isHTML ? HTMLOption : TextOption;
    return (
      <React.Fragment>
        {locales.length > 1 ? (
          <table className="localeTable">
            <tbody>
              {locales.map(locale => (
                <tr key={locale}>
                  <td>{localeNames[locale]}</td>
                  <td>
                    <Option name={"locales." + locale + "." + this.props.name} db={this.props.db} dir={(locale == "ar") ? "rtl" : null} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          locales.map(locale => (
            <Option key={locale} name={"locales." + locale + "." + this.props.name} db={this.props.db} dir={(locale == "ar") ? "rtl" : null} />
          ))
        )}
        {showReset &&
          <div className="text-reset">
            <a href="#" onClick={this.handleReset}>Reset</a>
          </div>
        }
      </React.Fragment>
    );
  }
}

// PseudoBoolean means the value is not a boolean (it's usually a text or a number),
// but we use a checkbox for it.
class PseudoBooleanOption extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
  }

  handleChange(event) {
    const checked = event.target.checked;
    this.props.db.set(this.props.name, checked ? this.props.defaultTrueValue : this.props.falseValue);
  }

  render() {
    return (
      <div className="form-check">
        <input type="checkbox" className="form-check-input" checked={this.props.db.get(this.props.name) !== this.props.falseValue} onChange={this.handleChange} />
        <label className="form-check-label">{this.props.label}</label>
      </div>
    );
  }
}

class DateOption extends React.Component {
  render() {
    return (
      <DateInput onChange={value => { this.props.db.set(this.props.name, value); }} value={this.props.db.get(this.props.name)} />
    );
  }
}

class AdvancedWorkflowOption extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      isEditing: false,
      text: ""
    };
    this.handleInputChange = this.handleInputChange.bind(this);
    this.handleFocus = this.handleFocus.bind(this);
    this.handleBlur = this.handleBlur.bind(this);
  }

  handleInputChange(event) {
    const text = event.target.value;
    this.setState({text: text});
    this.props.db.set(this.props.name, this.toValue(text));
  }

  handleFocus() {
    this.setState({ isEditing: true, text: this.toText(this.props.db.get(this.props.name)) });
  }

  handleBlur() {
    this.setState({ isEditing: false });
  }

  toValue(text) {
    try {
      const value = jsyaml.safeLoad(text, {schema: jsyaml.JSON_SCHEMA});
      // Need to check for undefined because jsyaml.safeLoad('') returns undefined.
      if (value === undefined)
        return text;
      return value;
    } catch (e) {
    }
    return text;
  }

  toText(value) {
    if (typeof value == "string") {
      return value;
    }
    return jsyaml.safeDump(value, {schema: jsyaml.JSON_SCHEMA, flowLevel: 0, lineWidth: -1});
  }

  checkError(value) {
    const pages = ["approval", "thanks_approval", "question", "comparison", "knapsack", "token", "ranking", "survey", "thanks"];
    if (!(value instanceof Array))
      return "Workflow must be an array of allowed pages. For example, [approval, thanks]";
    for (let x of value) {
      if (x instanceof Array) {
        for (let y of x) {
          if (pages.indexOf(y) == -1) {
            return "\"" + y + "\" is not an allowed page.";
          }
        }
      } else if (pages.indexOf(x) == -1) {
        return "\"" + x + "\" is not an allowed page.";
      }
    }
    if (value.length == 0)
      return "Workflow must contain at least one page.";
    if (value[value.length - 1] != "thanks")
      return "The last page must be \"thanks\".";
    return null;
  }

  render() {
    const value = this.props.db.get(this.props.name);
    const text = this.state.isEditing ? this.state.text : this.toText(value);
    const error = this.checkError(value);
    return (
      <React.Fragment>
        <input type="text" className="form-control" onChange={this.handleInputChange} value={text} onFocus={this.handleFocus} onBlur={this.handleBlur} />
        {error ? (<div className="text-danger">{error}</div>) : null}
        <div className="help-block">
          An array of pages that each voter sees. Allowed pages are
          <ul><li>approval</li><li>thanks_approval</li><li>comparison</li><li>knapsack</li><li>ranking</li><li>token</li><li>question</li><li>survey</li><li>thanks</li></ul>
          If workflow contains a subarray, one of the pages in the subarray will be randomly chosen to show to the voter. For example, if you use "[approval, thanks_approval, [comparison, knapsack], survey, thanks]", one interface out of comparison and knapsack will be chosen randomly.
        </div>
      </React.Fragment>
    );
  }
}

class WorkflowOption extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      isSimple: this.isSimple()
    };

    this.handleUseSimple = this.handleUseSimple.bind(this);
    this.handleUseAdvanced = this.handleUseAdvanced.bind(this);
    this.handlePageChange = this.handlePageChange.bind(this);
    this.handleSurveyChange = this.handleSurveyChange.bind(this);

    this.pages = [
      ["approval", "Approval voting", "Voters select a set of projects. There is a limit on the number of projects, but there is <em>no</em> limit on the total cost."],
      ["knapsack", "Knapsack voting", "Voters select a set of projects. There is <em>no</em> limit on the number of projects, but there is a limit on the total cost."],
      ["ranking", "Ranked voting", "Voters select a set of projects and then rank them."],
      ["token", "Token voting", "Voters select a set of projects and assign them a number of tokens. There is a limit on the total tokens available. (Experimental method)"],
      ["comparison", "Comparison voting", "Voters compare pairs of projects that are randomly chosen."]
    ];
  }

  handleUseSimple(event) {
    event.preventDefault();
    if (this.isSimple()) {
      this.setState({isSimple: true});
    } else {
      if (confirm("It looks like you are using multiple voting methods or the workflow contains a page that can't be edited with the simple workflow editor. Are you sure you still want to use it? WARNING: Some data may be lost.")) {
        let workflow = this.props.db.get(this.props.name);
        const hasSurvey = (workflow instanceof Array) && workflow.indexOf("survey") != -1;
        if (hasSurvey) {
          workflow = ["approval", "thanks_approval", "survey", "thanks"];
        } else {
          workflow = ["approval", "thanks"];
        }
        this.props.db.set(this.props.name, workflow);
        this.setState({isSimple: true});
      }
    }
  }

  handleUseAdvanced(event) {
    event.preventDefault();
    this.setState({isSimple: false});
  }

  handlePageChange(event, page) {
    const workflow = this.props.db.get(this.props.name).slice(0);
    workflow[0] = page;
    this.props.db.set(this.props.name, workflow);
  }

  handleSurveyChange(event) {
    const checked = event.target.checked;
    const workflow = this.props.db.get(this.props.name).slice(0);
    if (checked) {
      workflow.splice(workflow.length - 1, 0, "thanks_approval", "survey");
    } else {
      workflow.splice(workflow.length - 3, 2);
    }
    this.props.db.set(this.props.name, workflow);
  }

  isSimple() {
    // "Simple" workflow can be defined in terms of regular expressions as
    // "(approval|knapsack|ranking|token|comparison) (thanks_approval survey)? thanks"
    const workflow = this.props.db.get(this.props.name);
    if (!(workflow instanceof Array) || workflow.length < 2)
      return false;
    if (["approval", "knapsack", "ranking", "token", "comparison"].indexOf(workflow[0]) == -1)
      return false;
    let i = 1;
    if (workflow[i] == "thanks_approval") {
      i += 1;
      if (i >= workflow.length || workflow[i] != "survey") {
        return false;
      }
      i += 1;
    }
    if (i != workflow.length - 1 || workflow[i] != "thanks")
      return false;
    return true;
  }

  render() {
    // We manage voting method and survey within the same "workflow" option.
    // But this is not intuitive to users. So, we split it into two modes:
    // "voting_method" and "survey".
    // The "voting_method" mode is shown under the General tab.
    // The "survey" mode is shown under the Survey tab.

    // Survey mode
    if (this.props.mode == "survey") {
      if (!this.isSimple()) {
        // FIXME: Reword this.
        return "If you'd like to add/remove a survey at the end of the vote, add/remove \"survey\" in the array in the \"Voting method\" section under the General tab.";
      }
      const workflow = this.props.db.get(this.props.name);
      const hasSurvey = workflow[workflow.length - 2] == "survey";
      return (
        <div className="form-check">
          <input type="checkbox" className="form-check-input" checked={hasSurvey} onChange={this.handleSurveyChange} id={this.props.name + "_survey"} />
          <label className="form-check-label" htmlFor={this.props.name + "_survey"}>Have a survey at the end of the vote.</label>
        </div>
      );
    }

    // Voting_method mode
    if (!this.state.isSimple) {
      return (
        <React.Fragment>
          <AdvancedWorkflowOption name={this.props.name} db={this.props.db} />
          {/* FIXME: Allow the first page to be subarray. (Not related to this code) */}
          <div className="help-block">If you want to use only one voting method, you can use the <a href="#" onClick={this.handleUseSimple}>simple workflow editor</a>.</div>
        </React.Fragment>
      );
    }
    const workflow = this.props.db.get(this.props.name);
    const firstPage = workflow[0];
    return (
      <React.Fragment>
        {this.pages.map(x => {
          const page = x[0];
          return (
            <div key={page} className="form-check">
              <input type="radio" className="form-check-input" checked={firstPage == page} onChange={e => { this.handlePageChange(e, page); }} id={this.props.name + "_" + page} />
              <label className="form-check-label" htmlFor={this.props.name + "_" + page}>
                <span className="font-weight-lightbold">{x[1]}</span>: <span dangerouslySetInnerHTML={{__html: x[2]}} />
              </label>
            </div>
          );
        })}

        {/*<div className="help-block">This is the order of pages that voters see: ...</div>*/}
        <div className="help-block mt-1">If you want to use multiple voting methods, use the <a href="#" onClick={this.handleUseAdvanced}>advanced workflow editor</a>.</div>
      </React.Fragment>
    );
  }
}

function PagePreview(props) {
  const shuffled = props.shuffleProjects;
  const nColumns = Math.max(Math.min(props.nCols, 3), 1);
  const letters = shuffled ? ["B", "D", "A", "C", "F", "E", "G", "I", "H"] : ["A", "B", "C", "D", "E", "F", "G", "H", "I"];
  return (
    <div className="preview-wrapper">
      <table className={"preview preview-theme" + props.theme}>
        <tbody>
        {props.tokenbar &&
            <tr>
              <td colSpan="2" className="preview-tokenbar">
                Selected 8 out of 20 tokens.
                <div className="progress">
                  <div className="progress-bar bg-success"></div>
                </div>
              </td>
            </tr>
        }
          {props.budgetbar &&
            <tr>
              <td colSpan="2" className="preview-budgetbar">
                Selected $400 of $1,000 total budget.
                <div className="progress">
                  <div className="progress-bar bg-success"></div>
                </div>
              </td>
            </tr>
          }
          
          <tr>
            {(props.sidebar || props.tracker) &&
              <td className="preview-leftbar">
                {props.tracker &&
                  <div>Selected<br /><b>1 / 4</b><br />projects.<br /><br /></div>
                }
                {props.sidebar &&
                  <div className="preview-sidebar">
                    <div>Project {letters[0]}</div>
                    <div className="preview-sidebar-selected">Project {letters[1]}</div>
                    <div>Project {letters[2]}</div>
                    <div>Project {letters[3]}</div>
                    <div>...</div>
                  </div>
                }
              </td>
            }
            <td className="preview-list">
              {props.topTracker &&
                <div className="preview-topTracker">Selected <b>1 / 4</b> projects.</div>
              }
              <b>Instructions</b><br />...<br />
              {shuffled && props.showShuffleNote && <div>These projects are arranged in a random order.</div>}
              <br />

              <div className="preview-project">
                {(function() {
                  const rows = [];
                  for (let i = 0; i < 3; ++i) {
                    rows.push(
                      <div key={i} className="preview-project-row">
                        {(function() {
                          const cols = [];
                          for (let j = 0; j < nColumns; ++j) {
                            const k = i * nColumns + j;
                            cols.push(
                              <div key={j} className={"preview-project-cell" + ((k == 1) ? " preview-project-cell-selected" : "")}>
                                Project {letters[k]}<br />...
                              </div>
                            );
                          }
                          return cols;
                        })()}
                      </div>
                    );
                  }
                  return rows;
                })()}
              </div>

            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}


function ProjectPreview(props) {
  return (
    <div className="projectPreview">
      {props.showMaps &&
        <img src="/img/preview_map.png" width="80" height="78" />
      }
      <p><b>{props.showNumbers && "1. "}Project A {props.showCostInTitle && "($100,000)"}</b><br />
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore.</p>
      {props.showCost &&
        <p><b>Estimated Cost</b>: {props.currencySymbol}100,000</p>
      }
      {props.isToken &&
        <p><b>Tokens used</b>:  5</p>
        
      }
      {props.isToken &&
        <button type="button" class="btn btn-primary btn-lg" id="plus-button20">+ </button>
        
      }

      {props.isToken &&
        <b>&nbsp; &nbsp;</b>
      }


      {props.isToken &&
        <button type="button" class="btn btn-secondary btn-lg" id="minus-button20">&minus; </button>
      }
      {!props.isToken &&
        <button className="btn btn-primary">Select</button>
      
      }
    </div>
  );
}


class TimeZoneOption extends React.Component {
  shouldComponentUpdate(nextProps) { // Just an optimization.
    return false;
  }

  render() {
    return (
      <select className="form-control" name="election[time_zone]" defaultValue={electionData.time_zone}>
        {timeZones.map((timeZone, index) => (
          <option key={index} value={timeZone[1]}>{timeZone[0]}</option>
        ))}
      </select>
    );
  }
}


class ConfigEditor extends React.Component {
  constructor(props) {
    super(props);
    this.props.db.setCallback(() => {
      this.forceUpdate();
    });
  }

  render() {
    const db = this.props.db;
    const c = db.get;

    let flattenedWorkflow = null;
    const workflow = c('workflow');
    if (workflow instanceof Array) {
      flattenedWorkflow = [];
      for (let page of workflow) {
        if (page instanceof Array) {
          flattenedWorkflow = flattenedWorkflow.concat(page);
        } else {
          flattenedWorkflow.push(page);
        }
      }
    }

    return (
      <React.Fragment>
        <ul className="nav nav-tabs mb-3" role="tablist">
          <li className="nav-item"><a className="nav-link active" data-toggle="tab" href="#general-tab" role="tab">General</a></li>
          <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#home-tab" role="tab">Home Page</a></li>
          {flattenedWorkflow && flattenedWorkflow.indexOf('approval') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#approval-tab" role="tab">Approval Voting</a></li>
          )}
          {flattenedWorkflow && flattenedWorkflow.indexOf('knapsack') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#knapsack-tab" role="tab">Knapsack Voting</a></li>
          )}
          {flattenedWorkflow && flattenedWorkflow.indexOf('token') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#token-tab" role="tab">Token Voting</a></li>
          )}
          {flattenedWorkflow && flattenedWorkflow.indexOf('ranking') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#ranking-tab" role="tab">Ranked Voting</a></li>
          )}
          {flattenedWorkflow && flattenedWorkflow.indexOf('comparison') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#comparison-tab" role="tab">Comparison Voting</a></li>
          )}
          {flattenedWorkflow && flattenedWorkflow.indexOf('question') != -1 && (
            <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#question-tab" role="tab">Question Page</a></li>
          )}
          <li className="nav-item"><a className="nav-link" data-toggle="tab" href="#survey-tab" role="tab">Survey</a></li>
        </ul>

        <div className="tab-content">
          <div className="tab-pane show active" id="general-tab" role="tabpanel">

<div className="group">
  <label className="group-title">Basic info</label>
  <div className="group-body">
    <table className="basicInfoTable">
      <tbody>
        <tr>
          <td><label htmlFor="election_name">Name</label></td>
          <td><input className="form-control" type="text" name="election[name]" id="election_name" defaultValue={electionData.name} /></td>
        </tr>
        <tr>
          <td><label htmlFor="election_slug">URL</label></td>
          <td>
            <div className="input-group">
              <div className="input-group-prepend"><div className="input-group-text">{hostWithPort}/</div></div>
              <input className="form-control" type="text" name="election[slug]" id="election_slug" defaultValue={electionData.slug} />
            </div>
          </td>
        </tr>
        <tr>
          <td><label htmlFor="election_budget">Budget</label></td>
          <td>
            <div className="form-inline">
              <SelectOption name="currency_symbol" db={db} values={[["$","$"],["€","€"],["£","£"],["¥","¥"],["₹","₹"],["CHF","CHF"],["zł","zł"]]} />
              &nbsp;
              <input className="form-control" type="number" name="election[budget]" id="election_budget" defaultValue={electionData.budget} />
            </div>
          </td>
        </tr>
        <tr>
          <td>Time zone</td>
          <td>
            <div className="form-inline">
              <TimeZoneOption />
            </div>
          </td>
        </tr>
        <tr>
          <td>Dates</td>
          <td>
            <div className="form-inline">
              <DateOption name="start_date" db={db} />
              &nbsp;-&nbsp;
              <DateOption name="end_date" db={db} />
            </div>
            {/* ((value)=>((value == '' || dateRegex.test(value)) ? null : (<div className="text-danger">The date must be in the MM/DD/YYYY format or blank.</div>) ))(db.get("start_date")) */}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

{isCurrentUserSuperadmin && // FIXME: Weird hidden form.
  <div className="group">
    <span className="group-info">(Only superadmins can see this)</span>
    <label className="group-title">Superadmin settings</label>
    <div className="group-body">
      <div className="form-check">
        <input name="election[allow_admins_to_update_election]" type="hidden" value="0" />
        <input type="checkbox" className="form-check-input" value="1" name="election[allow_admins_to_update_election]" id="election_allow_admins_to_update_election" defaultChecked={electionData.allow_admins_to_update_election} />
        <label className="form-check-label" htmlFor="election_allow_admins_to_update_election">Allow admins to change the config and projects.</label>
      </div>
      <div className="form-check">
        <input name="election[allow_admins_to_see_voter_data]" type="hidden" value="0" />
        <input type="checkbox" className="form-check-input" value="1" name="election[allow_admins_to_see_voter_data]" id="election_allow_admins_to_see_voter_data" defaultChecked={electionData.allow_admins_to_see_voter_data} />
        <label className="form-check-label" htmlFor="election_allow_admins_to_see_voter_data">Allow admins to see the individual votes and voter registration records in the analytics.</label>
      </div>
      <div className="form-check">
        <input name="election[allow_admins_to_see_exact_results]" type="hidden" value="0" />
        <input type="checkbox" className="form-check-input" value="1" name="election[allow_admins_to_see_exact_results]" id="election_allow_admins_to_see_exact_results" defaultChecked={electionData.allow_admins_to_see_exact_results} />
        <label className="form-check-label" htmlFor="election_allow_admins_to_see_exact_results">Allow admins to see the exact vote results in the analytics. If not allowed, the results will be rounded to the nearest 10.</label>
      </div>

      <div className="form-check">
        <input name="election[real_election]" type="hidden" value="0" />
        <input type="checkbox" className="form-check-input" value="1" name="election[real_election]" id="election_real_election" defaultChecked={electionData.real_election} />
        <label className="form-check-label" htmlFor="election_real_election">Real PB (not a demo or a test)</label>
      </div>

      <div className="mt-1">Remarks:</div>
      <textarea rows="2" className="form-control" name="election[remarks]" defaultValue={electionData.remarks} />
    </div>
  </div>
}

<div className="group">
  <label className="group-title">Languages</label>
  <div className="group-body">
    <div>Available languages:</div>
    <CheckboxOption name="available_locales" db={db} values={[["en","English"],["am","Amharic"],["ar","Arabic"],["bn","Bengali"],["zh","Chinese"],["fi","Finnish"],["fr","French"],["de","German"],["ht","Haitian Creole"],["hi","Hindi"],["mww", "Hmong (Hmong Daw)"],["km","Khmer"],["pl","Polish"],["pt","Portuguese"],["ru","Russian"],["es","Spanish"],["tl","Tagalog/Filipino"],["uk","Ukrainian"]]} />
    { ((value)=>((value.length >= 1) ? null : (<div className="text-danger">Select at least one language.</div>) ))(db.get("available_locales")) }

    <div className="form-inline">
      <span className="mr-2">Default language:</span>
      <SelectOption name="default_locale" db={db} values={[["en","English"],["am","Amharic"],["ar","Arabic"],["bn","Bengali"],["zh","Chinese"],["fi","Finnish"],["fr","French"],["de","German"],["ht","Haitian Creole"],["hi","Hindi"],["mww", "Hmong (Hmong Daw)"],["km","Khmer"],["pl","Polish"],["pt","Portuguese"],["ru","Russian"],["es","Spanish"],["tl","Tagalog/Filipino"],["uk","Ukrainian"]]} />
    </div>
    { ((value)=>((c('available_locales').indexOf(value) != -1) ? null : (<div className="text-danger">Must be a language that is available.</div>) ))(db.get("default_locale")) }
  </div>
</div>

<div className="group">
  <label className="group-title">Ballot access</label>
  <div className="group-body">
    <div>Choose how people can access the ballot and vote:</div>
    <BooleanOption name="allow_local_voting" db={db} label="In-person digital voting (i.e., you set up computers at a certain place where people come in and vote)" />
    <BooleanOption name="allow_remote_voting" db={db} label="Remote voting (i.e., allow people to vote from their home on their computer/smartphone)" />

    {(db.get("allow_local_voting") || db.get("allow_remote_voting")) ? null : (<div className="text-danger">Choose at least one option.</div>
    )}
  </div>
</div>

<Conditional condition={c('allow_remote_voting')} names={["remote_voting_sms_verification", "remote_voting_other_verification", "remote_voting_code_verification"]} db={db}>
  <div className="group">
    <label className="group-title">Remote voter validation</label>
    <div className="group-body">
      <div>Choose how to validate people who vote from their home. (See the  <a href="#" data-toggle="modal" data-target="#remoteVoterValidationExplanationModal">explanation for each validation method</a>.)</div>
      <BooleanOption name="remote_voting_sms_verification" db={db} label="Remote voting using SMS confirmation" />
      <BooleanOption name="remote_voting_other_verification" db={db} label="Remote voting using personal information" />
      <BooleanOption name="remote_voting_code_verification" db={db} label="Remote voting using generated codes" />
      <BooleanOption name="remote_voting_free_verification" db={db} label="Remote voting using free-form text field (no verification)" />

      {db.get("allow_remote_voting") && (
        (db.get("remote_voting_sms_verification") || db.get("remote_voting_other_verification") || db.get("remote_voting_code_verification") || db.get("remote_voting_free_verification")) ? null : (<div className="text-danger">Select at least one validation method.</div>)
      )}
      {db.get("allow_remote_voting") && (
        (db.get("remote_voting_sms_verification") && !db.get("remote_voting_other_verification") && !db.get("remote_voting_code_verification")) ? (<div className="text-danger">It is recommended that you also use other validation methods in addition to SMS. Some voters might not have a cell phone that can receive SMS.</div>) : null
      )}

      <Conditional condition={c('allow_remote_voting') && c('remote_voting_code_verification')} db={db}>
        <div className="mt-1">Your email address or phone number that voters can call to get an access code:</div>
        <LocalizedTextOption name="code_signup.instruction" db={db} />
      </Conditional>
    </div>
  </div>
</Conditional>

<Conditional condition={c('allow_remote_voting') && c('remote_voting_other_verification')} db={db}>
  <div className="group">
    <label className="group-title">Remote voting using personal information</label>
    <div className="group-body">
      <div>Header:</div>
      <LocalizedTextOption name="other_signup.title" db={db} isHTML={false} />

      <div className="mt-2">Instructions:</div>
      <LocalizedTextOption name="other_signup.instruction" db={db} />

      <div className="mt-2">Account number placeholder:</div>
      <LocalizedTextOption name="other_signup.account_number_placeholder" db={db} isHTML={false} />

      <div className="mt-2">Postal code placeholder:</div>
      <LocalizedTextOption name="other_signup.zipcode_placeholder" db={db} isHTML={false} />

      <div className="mt-2">Instructions on what to do if voters don't have an account number:</div>
      <LocalizedTextOption name="other_signup.no_account_number_instruction" db={db} />

      <div className="mt-2">Error message for wrong account numbers:</div>
      <LocalizedTextOption name="other_signup.wrong_account_number" db={db} isHTML={false} />
    </div>
  </div>
</Conditional>

<Conditional condition={c('allow_remote_voting') && c('remote_voting_free_verification')} db={db}>
  <div className="group">
    <label className="group-title">Remote voting using using free-form text field</label>
    <div className="group-body">
      <div>Header:</div>
      <LocalizedTextOption name="free_signup.title" db={db} isHTML={false} />

      <div className="mt-2">Instructions:</div>
      <LocalizedTextOption name="free_signup.instruction" db={db} isHTML={false} />

      <div className="mt-2">Text field placeholder:</div>
      <LocalizedTextOption name="free_signup.placeholder" db={db} isHTML={false} />

      <BooleanOption name="free_verification_multiline_text" db={db} label="Accept multiline text" />
      <BooleanOption name="free_verification_use_captcha" db={db} label="Use CAPTCHA" />
    </div>
  </div>
</Conditional>

<div className="group">
  <label className="group-title">Voter registration</label>
  <div className="group-body">
    <BooleanOption name="voter_registration" db={db} label="Ask voters for some personal information before they vote." />

    <Conditional condition={c('voter_registration')} name="voter_registration_questions" db={db}>
      <div className="mt-1">Ask the following questions:</div>
      <CheckboxOption name="voter_registration_questions" db={db} values={[["name","Name"],["first_name","First name"],["middle_initial","Middle initial (optional)"],["last_name","Last name"],["suffix","Suffix (optional)"],["address","Address"],["city","City"],["zip_code","ZIP code"],["phone_number","Phone number (optional)"],["birth_year","Birth year"],["date_of_birth","Date of birth (select this if you'd like to check voters' ages)"],["email","Email (optional)"],["ward","Ward"],["age_verify","Ask voters to certify that they are eligible to vote (For example, \"I am over ... years old\", \"I live in ...\", etc.)"]]} />
      { ((value)=>((value.length >= 1) ? null : (<div className="text-danger">Select at least one question.</div>) ))(db.get("voter_registration_questions")) }
    </Conditional>

    <Conditional condition={c('voter_registration') && c('voter_registration_questions').indexOf('age_verify') != -1} db={db}>
      <div className="mt-2">The statement to certify:</div>
      <LocalizedTextOption name="registration.verify_age_label" db={db} showReset={false} isHTML={false} />
    </Conditional>
  </div>
</div>

<Conditional condition={c('voter_registration') && c('voter_registration_questions').indexOf('date_of_birth') != -1} names={["minimum_voting_age", "maximum_voting_age", "age_as_of_date"]} db={db}>
  <div className="group">
    <label className="group-title">Voting age</label>
    <div className="group-body">
      <div className="form-inline">
        <div className="mr-2">Minimum age:</div>
        <NumberOption name="minimum_voting_age" db={db} appendText="years" showEmptyStringForZero={true} />
      </div>
      <div className="help-block">Leave blank for no mimimum voting age.</div>

      <div className="form-inline">
        <div className="mr-2">Maximum age:</div>
        <NumberOption name="maximum_voting_age" db={db} appendText="years" showEmptyStringForZero={true} />
      </div>
      <div className="help-block">Leave blank for no maximum voting age.</div>

      <Conditional condition={c('minimum_voting_age') > 0 || c('maximum_voting_age') > 0} name="age_as_of_date" db={db}>
        <div className="form-inline">
          <div className="mr-2">As of date:</div>
          <DateOption name="age_as_of_date" db={db} />
        </div>
        <div className="help-block">Check the voter's age as of specified date. If blank, check the voter's age as of today.</div>
        {/*
        { ((value)=>((value == '' || dateRegex.test(value)) ? null : (<div className="text-danger">The date must be in the MM/DD/YYYY format or blank.</div>) ))(db.get("age_as_of_date")) }
        */}
      </Conditional>
    </div>
  </div>
</Conditional>

<div className="group">
  <label className="group-title">Voting method</label>
  <div className="group-body">
    <WorkflowOption name="workflow" db={db} mode="voting_method" />
  </div>
</div>

{/*
<div className="group">
  <label className="group-title">Send vote SMS</label>
  <div className="group-body">
    <BooleanOption name="send_vote_sms" db={db} label="Send an SMS to the voter after they vote to confirm that we have received their vote." />
    <div className="help-block">To use this option, the voter registration option must be enabled, and the voter registration questions must include phone numbers.</div>
  </div>
</div>
*/}

<div className="group">
  <label className="group-title">Brand</label>
  <div className="group-body">
    <LocalizedTextOption name="navigation.brand" db={db} showReset={false} isHTML={false} />
    <div className="help-block">The text on the top-left corner of every page. Use no more than 20 characters, so that it can fit on a small screen.</div>
  </div>
</div>

{/*
<div className="group">
  <label className="group-title">External redirect URL</label>
  <div className="group-body">
    <TextOption name="external_redirect_url" db={db} />
    <div className="help-block">The URL to redirect the voter to after they reach the last page. If blank, the voter will return to the home page.</div>
  </div>
</div>

<div className="group">
  <label className="group-title">Timeout</label>
  <div className="group-body">
    <div className="form-inline">
      <NumberOption name="timeout" db={db} appendText="seconds" />
    </div>
    <div className="help-block">If the voter doesn't interact with the website (i.e., doesn't move their mouse) for this amount of time, return to the home page. Use 0 for no timeout.</div>
  </div>
</div>
*/}

<div className="group">
  <label className="group-title">Miscellaneous</label>
  <div className="group-body">
    <PseudoBooleanOption name="external_redirect_url" db={db} falseValue="" defaultTrueValue="https://" label={
      <React.Fragment>
        After a voter reaches the last page, redirect them to <div className="form-inline" style={{display: "inline-block", marginTop: "-4px"}}><TextOption name="external_redirect_url" db={db} placeholder="https://..." /></div> (If blank, return to the home page.)
      </React.Fragment>
    } />

    {/*
    <PseudoBooleanOption name="timeout" db={db} falseValue={0} defaultTrueValue={600} label={
      <React.Fragment>
        If a voter doesn't interact with the website (i.e., don't move their mouse)
        for <div className="form-inline timeout" style={{display: "inline-block"}}><NumberOption name="timeout" db={db} multiplier={60} showEmptyStringForZero={true} /></div> minutes, end their session and return to the home page.
      </React.Fragment>
    } />
    */}
 </div>
</div>

<div className="group">
  <label className="group-title">Voting logistics</label>
  <div className="group-body">
    <BooleanOption name="stop_accepting_votes" db={db} label="Stop accepting votes" />
    <div className="help-block">Use this option to disable voting before the PB starts and after the PB ends.</div>

    <BooleanOption name="voting_has_ended" db={db} label="Show the text &quot;The voting has ended&quot; on the home page" />

    <BooleanOption name="show_public_results" db={db} label="Show the voting results on the home page (Works only for approval)" />
  </div>
</div>
          </div>


          <div className="tab-pane" id="home-tab" role="tabpanel">

<div className="group">
  <label className="group-title">Welcome text for remote voting</label>
  <div className="group-body">
    <div>The welcome text for people who view this website from their home:</div>
    <LocalizedTextOption name="index.remote.welcome" db={db} />
  </div>
</div>

<Conditional condition={c('allow_local_voting')} db={db}>
  <div className="group">
    <label className="group-title">Welcome text for in-person digital voting</label>
    <div className="group-body">
      <div>The welcome text for people who view this website at the local voting station:</div>
      <LocalizedTextOption name="index.voting_machine.welcome" db={db} />
    </div>
  </div>
</Conditional>

<div className="group">
  <label className="group-title">Buttons</label>
  <div className="group-body">
    <BooleanOption name="index.show_explore_button" db={db} label="Show the button that lets people take a look at the ballot without voting. (There will be a text warning them that it's only a preview.)" />
    <Conditional condition={c('index.show_explore_button')} db={db}>
      <div>The text on the button:</div>
      <LocalizedTextOption name="index.remote.proceed_button" db={db} isHTML={false} />
    </Conditional>

    <Conditional condition={c('allow_remote_voting') && c('remote_voting_sms_verification')} name="index.show_remote_voting_sms_button" db={db}>
      <BooleanOption name="index.show_remote_voting_sms_button" db={db} label="Show the button for remote voting using SMS" />
      <Conditional condition={c('index.show_remote_voting_sms_button')} db={db}>
        <div>The text on the button:</div>
        <LocalizedTextOption name="index.remote.sms_verification_button" db={db} isHTML={false} />
      </Conditional>
    </Conditional>

    <Conditional condition={c('allow_remote_voting') && c('remote_voting_other_verification')} name="index.show_remote_voting_other_button" db={db}>
      <BooleanOption name="index.show_remote_voting_other_button" db={db} label="Show the button for remote voting using personal information" />
      <Conditional condition={c('index.show_remote_voting_other_button')} db={db}>
        <div>The text on the button:</div>
        <LocalizedTextOption name="index.remote.other_verification_button" db={db} isHTML={false} />
      </Conditional>
    </Conditional>

    <Conditional condition={c('allow_remote_voting') && c('remote_voting_code_verification')} name="index.show_remote_voting_code_button" db={db}>
      <BooleanOption name="index.show_remote_voting_code_button" db={db} label="Show the button for remote voting using generated codes" />
      <Conditional condition={c('index.show_remote_voting_code_button')} db={db}>
        <div>The text on the button:</div>
        <LocalizedTextOption name="index.remote.code_verification_button" db={db} isHTML={false} />
      </Conditional>
    </Conditional>

    <Conditional condition={c('allow_remote_voting') && c('remote_voting_free_verification')} name="index.show_remote_voting_free_button" db={db}>
      <BooleanOption name="index.show_remote_voting_free_button" db={db} label="Show the button for remote voting using free-form text field" />
      <Conditional condition={c('index.show_remote_voting_free_button')} db={db}>
        <div>The text on the button:</div>
        <LocalizedTextOption name="index.remote.code_verification_button" db={db} isHTML={false} />
      </Conditional>
    </Conditional>

    <PseudoBooleanOption name="index.see_projects_url" db={db} falseValue="" defaultTrueValue="https://" label={
      <React.Fragment>
        Show the button for the external URL:&nbsp;
        <div className="form-inline" style={{display: "inline-block", marginTop: "-4px"}}>
          <TextOption name="index.see_projects_url" db={db} placeholder="https://..." />
        </div>
      </React.Fragment>
    } />
    <Conditional condition={c('index.see_projects_url') && c('index.see_projects_url').length > 0} db={db}>
      <div>The text on the button:</div>
      <LocalizedTextOption name="index.remote.see_projects_button" db={db} isHTML={false} />
    </Conditional>
  </div>
</div>

{/*
<div className="group">
  <label className="group-title">Button for external URL</label>
  <div className="group-body">
    <TextOption name="index.see_projects_url" db={db} />
    <div className="help-block">If not blank, this will create a button on the home page that opens the given URL when clicked.</div>

    <Conditional condition={c('index.see_projects_url') && c('index.see_projects_url').length > 0} db={db}>
      <div className="mt-2">The text on the button:</div>
      <LocalizedTextOption name="index.remote.see_projects_button" db={db} isHTML={false} />
    </Conditional>
  </div>
</div>
*/}

<div className="group">
  <label className="group-title">Election info</label>
  <div className="group-body">
    <div>Information about the voting places, locations, and any additional information:</div>
    <LocalizedTextOption name="election.info" db={db} />
  </div>
</div>

          </div>

          <div className="tab-pane" id="approval-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('approval') != -1} name="approval" db={db}>

  <div className="group">
    <label className="group-title">Page appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="approval.sidebar" db={db} label="Show the project list on the left side" />

        <BooleanOption name="approval.tracker" db={db} label="Show the project counter" />

        <BooleanOption name="approval.top_tracker" db={db} label="Show the project counter on top" />

        <BooleanOption name="approval.shuffle_projects" db={db} label="Randomize the order of projects" />

        <Conditional condition={c('approval.shuffle_projects')} name="approval.show_shuffle_note" db={db}>
          <BooleanOption name="approval.show_shuffle_note" db={db} label="Let voters know that the order of projects is randomized" />
        </Conditional>

        <div className="mt-1">Number of columns:</div>
        <NumberOption name="approval.n_cols" db={db} />

        <div className="mt-1">Theme:</div>
        <SelectOption name="approval.theme" db={db} values={[[0,"Light"],[1,"Gray"],[2,"Dark"]]} />
      </div>
      <div className="col-sm-5">
        <PagePreview
          budgetbar={db.get("approval.budgetbar")}
          shuffleProjects={db.get("approval.shuffle_projects")}
          nCols={db.get("approval.n_cols")}
          theme={db.get("approval.theme")}
          sidebar={db.get("approval.sidebar")}
          tracker={db.get("approval.tracker")}
          topTracker={db.get("approval.top_tracker")}
          showShuffleNote={db.get("approval.show_shuffle_note")}
        />
        <div className="previewCaption">Preview</div>
      </div>
    </div>
  </div>

  {/*
  <div className="group">
    <label className="group-title">Budgetbar</label>
    <div className="group-body">
      <BooleanOption name="approval.budgetbar" db={db} label="Budgetbar" />
      <div className="help-block">Show a budget bar at the top of the page.</div>
    </div>
  </div>
  */}


  {/*
  <Conditional condition={c('approval.shuffle_projects')} name="approval.shuffle_probability" db={db}>
    <div className="group">
      <label className="group-title">Shuffle probability</label>
      <div className="group-body">
        <NumberOption name="approval.shuffle_probability" db={db} />
        <div className="help-block">Probability that the projects are shuffled. Use 1 for "always shuffled." Use 0.5 for "shuffled half of the time."</div>
        { ((value)=>((0 < value && value <= 1) ? null : (<div className="text-danger">Value must be between (0, 1].</div>) ))(db.get("approval.shuffle_probability")) }
      </div>
    </div>
  </Conditional>
  */}

  <div className="group">
    <label className="group-title">Project appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="approval.show_cost" db={db} label="Show cost under the description" />
        <BooleanOption name="approval.show_cost_in_title" db={db} label="Show cost in the title" />
        <BooleanOption name="approval.show_numbers" db={db} label="Show project numbers" />
        <BooleanOption name="approval.show_maps" db={db} label="Show maps (for projects that have coordinates)" />
      </div>
      <div className="col-sm-5">
        <ProjectPreview
          showMaps={db.get("approval.show_maps")}
          showNumbers={db.get("approval.show_numbers")}
          showCostInTitle={db.get("approval.show_cost_in_title")}
          showCost={db.get("approval.show_cost")}
          currencySymbol={db.get("currency_symbol")}
          isToken = {false}
        />
        <div className="previewCaption">Preview</div>
      </div>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Popup</label>
    <div className="group-body">
      <BooleanOption name="approval.show_popup" db={db} label="Show a popup (dialog box) when the voter comes to this page" />

      <Conditional condition={c('approval.show_popup')} db={db}>
        <div className="mt-2">The text in the popup:</div>
        <LocalizedTextOption name="approval.popup.body" db={db} />
      </Conditional>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Instructions</label>
    <div className="group-body">
      <div>The instructions on how to vote:</div>
      <LocalizedTextOption name="approval.instructions" db={db} />
    </div>
  </div>

  {/*
  <div className="group">
    <label className="group-title">Has budget limit</label>
    <div className="group-body">
      <BooleanOption name="approval.has_budget_limit" db={db} label="Has budget limit" />
      <div className="help-block">Is there a limit on the total amount of money the voter can spend?</div>
    </div>
  </div>
  */}

  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="approval.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>


  <div className="group">
    <label className="group-title">Limit on number of projects</label>
    <div className="group-body">
      <BooleanOption name="approval.has_n_project_limit" db={db} label="Impose a limit on the number of projects the voter can choose" />
      <div className="help-block"></div>

      <Conditional condition={c('approval.has_n_project_limit')} name="approval.max_n_projects" db={db}>
        <NumberOption name="approval.max_n_projects" db={db} />
        { ((value)=>((value >= 1) ? null : (<div className="text-danger">Value must be at least 1.</div>) ))(db.get("approval.max_n_projects")) }
        <div className="help-block">The maximum number of projects the voter can choose.</div>
      </Conditional>

      <Conditional condition={c('approval.has_n_project_limit')} name="approval.min_n_projects" db={db}>
        <NumberOption name="approval.min_n_projects" db={db} />
        { ((value)=>((value >= 0) ? null : (<div className="text-danger">Value must be at least 0.</div>) ))(db.get("approval.min_n_projects")) }
        { ((value)=>((value <= c('approval.max_n_projects')) ? null : (<div className="text-danger">Value must not be greater than the maximum number of projects the voter can choose.</div>) ))(db.get("approval.min_n_projects")) }
        <div className="help-block">The minimum number of projects the voter must choose.</div>
      </Conditional>
    </div>
  </div>

  <Conditional condition={c('approval.has_n_project_limit') || c('approval.has_budget_limit')} name="approval.allow_selection_beyond_limits" db={db}>
    <div className="group">
      <label className="group-title">Allow selection beyond limits</label>
      <div className="group-body">
        <BooleanOption name="approval.allow_selection_beyond_limits" db={db} label="While the voter is selecting projects, allow them to exceed the limit(s) temporarily" />
        <div className="help-block">Even if this is enabled, we won't let them submit their vote anyway if it exceeds the limit.</div>
      </div>
    </div>
  </Conditional>

  
  {/*
  <div className="group">
    <label className="group-title">Project ranking</label>
    <div className="group-body">
      <BooleanOption name="approval.project_ranking" db={db} label="Make voters rank the projects they choose before submitting their vote" />
    </div>
  </div>
  */}

  {/*
  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="approval.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Show help</label>
    <div className="group-body">
      <BooleanOption name="approval.show_help" db={db} label="Show the Help link at the top-right corner" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Checkbox acknowledgment</label>
    <div className="group-body">
      <BooleanOption name="approval.checkbox_acknowledgment" db={db} label="Before a voter submits their vote, they must click a checkbox that says that they understand that they can't change their vote afterwards" />
    </div>
  </div>

  <Conditional condition={c('approval.sidebar')} name="approval.allow_select_in_sidebar" db={db}>
    <div className="group">
      <label className="group-title">Allow selection in sidebar</label>
      <div className="group-body">
        <BooleanOption name="approval.allow_select_in_sidebar" db={db} label="Allow voters to select projects in the project list on the left side of the page" />
      </div>
    </div>
  </Conditional>

  <div className="group">
    <label className="group-title">Reverse order of radio buttons for adjustable cost projects</label>
    <div className="group-body">
      <BooleanOption name="approval.reverse_order_of_radio_buttons_for_adjustable_cost_projects" db={db} label="Reverse order of radio buttons for adjustable cost projects" />
    </div>
  </div>
  */}

</Conditional>
          </div>


          <div className="tab-pane" id="knapsack-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('knapsack') != -1} name="knapsack" db={db}>

  <div className="group">
    <label className="group-title">Page appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="knapsack.budgetbar" db={db} label="Show the budget bar" />

        <BooleanOption name="knapsack.sidebar" db={db} label="Show the project list on the left side" />

        <BooleanOption name="knapsack.shuffle_projects" db={db} label="Randomize the order of projects" />

        <Conditional condition={c('knapsack.shuffle_projects')} name="knapsack.show_shuffle_note" db={db}>
          <BooleanOption name="knapsack.show_shuffle_note" db={db} label="Let voters know that the order of projects is randomized" />
        </Conditional>

        <div className="mt-1">Number of columns:</div>
        <NumberOption name="knapsack.n_cols" db={db} />

        <div className="mt-1">Theme:</div>
        <SelectOption name="knapsack.theme" db={db} values={[[0,"Light"],[1,"Gray"],[2,"Dark"]]} />
      </div>
      <div className="col-sm-5">

        <PagePreview
          budgetbar={db.get("knapsack.budgetbar")}
          shuffleProjects={db.get("knapsack.shuffle_projects")}
          nCols={db.get("knapsack.n_cols")}
          theme={db.get("knapsack.theme")}
          sidebar={db.get("knapsack.sidebar")}
          tracker={db.get("knapsack.tracker")}
          showShuffleNote={db.get("knapsack.show_shuffle_note")}
        />
        <div className="previewCaption">Preview</div>

      </div>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Project appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        
        <BooleanOption name="knapsack.show_cost" db={db} label="Show cost under the description" />
        <BooleanOption name="knapsack.show_cost_in_title" db={db} label="Show cost in the title" />
        <BooleanOption name="knapsack.show_numbers" db={db} label="Show project numbers" />
        <BooleanOption name="knapsack.show_maps" db={db} label="Show maps (for projects that have coordinates)" />
      </div>
      <div className="col-sm-5">
        <ProjectPreview
          showMaps={db.get("knapsack.show_maps")}
          showNumbers={db.get("knapsack.show_numbers")}
          showCostInTitle={db.get("knapsack.show_cost_in_title")}
          showCost={db.get("knapsack.show_cost")}
          currencySymbol={db.get("currency_symbol")}
          isToken = {false}
        />
        <div className="previewCaption">Preview</div>
      </div>
    </div>
  </div>
  
  

  <div className="group">
    <label className="group-title">Allow selection beyond limits</label>
    <div className="group-body">
      <BooleanOption name="knapsack.allow_selection_beyond_limits" db={db} label="While the voter is selecting projects, allow them to exceed the limit(s) temporarily" />
      <div className="help-block">Even if this is enabled, we won't let them submit their vote anyway if it exceeds the limit.</div>
    </div>
  </div>
  


  {/*
  <Conditional condition={c('knapsack.shuffle_projects')} name="knapsack.shuffle_probability" db={db}>
    <div className="group">
      <label className="group-title">Shuffle probability</label>
      <div className="group-body">
        <NumberOption name="knapsack.shuffle_probability" db={db} />
        <div className="help-block">Probability that the projects are shuffled. Use 1 for "always shuffled." Use 0.5 for "shuffled half of the time."</div>
        { ((value)=>((0 < value && value <= 1) ? null : (<div className="text-danger">Value must be between (0, 1].</div>) ))(db.get("knapsack.shuffle_probability")) }
      </div>
    </div>
  </Conditional>
  */}

  <div className="group">
    <label className="group-title">Popup</label>
    <div className="group-body">
      <BooleanOption name="knapsack.show_popup" db={db} label="Show a popup (dialog box) when the voter comes to this page" />

      <Conditional condition={c('knapsack.show_popup')} db={db}>
        <div className="mt-2">The text in the popup:</div>
        <LocalizedTextOption name="knapsack.popup.body" db={db} />
      </Conditional>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Instructions</label>
    <div className="group-body">
      <div>The instructions on how to vote:</div>
      <LocalizedTextOption name="knapsack.instructions" db={db} />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="knapsack.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Show help</label>
    <div className="group-body">
      <BooleanOption name="knapsack.show_help" db={db} label="Show the Help link at the top-right corner" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Checkbox acknowledgment</label>
    <div className="group-body">
      <BooleanOption name="knapsack.checkbox_acknowledgment" db={db} label="Before a voter submits their vote, they must click a checkbox that says that they understand that they can't change their vote afterwards" />
    </div>
  </div>

</Conditional>
          </div>


          <div className="tab-pane" id="token-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('token') != -1} name="token" db={db}>

  <div className="group">
    <label className="group-title">Page appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="token.tokenbar" db={db} label="Show the token count" />

        <BooleanOption name="token.sidebar" db={db} label="Show the project list on the left side" />

        <BooleanOption name="token.shuffle_projects" db={db} label="Randomize the order of projects" />

        <Conditional condition={c('token.shuffle_projects')} name="token.show_shuffle_note" db={db}>
          <BooleanOption name="token.show_shuffle_note" db={db} label="Let voters know that the order of projects is randomized" />
        </Conditional>

        <div className="mt-1">Number of columns:</div>
        <NumberOption name="token.n_cols" db={db} />

        <div className="mt-1">Theme:</div>
        <SelectOption name="token.theme" db={db} values={[[0,"Light"],[1,"Gray"],[2,"Dark"]]} />
      </div>
      <div className="col-sm-5">

        <PagePreview
          budgetbar={db.get("token.budgetbar")}
          tokenbar={db.get("token.tokenbar")}
          shuffleProjects={db.get("token.shuffle_projects")}
          nCols={db.get("token.n_cols")}
          theme={db.get("token.theme")}
          sidebar={db.get("token.sidebar")}
          tracker={db.get("token.tracker")}
          showShuffleNote={db.get("token.show_shuffle_note")}
        />
        <div className="previewCaption">Preview</div>

      </div>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Total number of tokens</label>
    
        
      <NumberOption name="token.total_tokens" db={db} label="total_tokens" />

     
  </div>

  <div className="group">
    <label className="group-title">Project appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        
        <BooleanOption name="token.show_cost" db={db} label="Show cost under the description" />
        <BooleanOption name="token.show_cost_in_title" db={db} label="Show cost in the title" />
        
        <BooleanOption name="token.show_numbers" db={db} label="Show project numbers" />
        <BooleanOption name="token.show_maps" db={db} label="Show maps (for projects that have coordinates)" />

        
      </div>
      <div className="col-sm-5">
        <ProjectPreview
          showMaps={db.get("token.show_maps")}
          showNumbers={db.get("token.show_numbers")}
          showCostInTitle={db.get("token.show_cost_in_title")}
          showCost={db.get("token.show_cost")}
          currencySymbol={db.get("currency_symbol")}
          isToken = {true}
        />
        <div className="previewCaption">Preview</div>
      </div>

      
    </div>
  </div>


  <div className="group">
    <label className="group-title">Allow selection beyond limits</label>
    <div className="group-body">
      <BooleanOption name="token.allow_selection_beyond_limits" db={db} label="While the voter is selecting projects, allow them to exceed the limit(s) temporarily" />
      <div className="help-block">Even if this is enabled, we won't let them submit their vote anyway if it exceeds the limit.</div>
    </div>
  </div>


  <div className="group">
    <label className="group-title">Popup</label>
    <div className="group-body">
      <BooleanOption name="token.show_popup" db={db} label="Show a popup (dialog box) when the voter comes to this page" />

      <Conditional condition={c('token.show_popup')} db={db}>
        <div className="mt-2">The text in the popup:</div>
        <LocalizedTextOption name="token.popup.body" db={db} />
      </Conditional>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Instructions</label>
    <div className="group-body">
      <div>The instructions on how to vote:</div>
      <LocalizedTextOption name="token.instructions" db={db} />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="token.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Show help</label>
    <div className="group-body">
      <BooleanOption name="token.show_help" db={db} label="Show the Help link at the top-right corner" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Checkbox acknowledgment</label>
    <div className="group-body">
      <BooleanOption name="token.checkbox_acknowledgment" db={db} label="Before a voter submits their vote, they must click a checkbox that says that they understand that they can't change their vote afterwards" />
    </div>
  </div>

</Conditional>
          </div>

          <div className="tab-pane" id="ranking-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('ranking') != -1} name="ranking" db={db}>

  <div className="group">
    <label className="group-title">Page appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="ranking.sidebar" db={db} label="Show the project list on the left side" />

        <BooleanOption name="ranking.tracker" db={db} label="Show the project counter" />

        <BooleanOption name="ranking.top_tracker" db={db} label="Show the project counter on top" />

        <BooleanOption name="ranking.shuffle_projects" db={db} label="Randomize the order of projects" />

        <Conditional condition={c('ranking.shuffle_projects')} name="ranking.show_shuffle_note" db={db}>
          <BooleanOption name="ranking.show_shuffle_note" db={db} label="Let voters know that the order of projects is randomized" />
        </Conditional>

        <div className="mt-1">Number of columns:</div>
        <NumberOption name="ranking.n_cols" db={db} />

        <div className="mt-1">Theme:</div>
        <SelectOption name="ranking.theme" db={db} values={[[0,"Light"],[1,"Gray"],[2,"Dark"]]} />
      </div>
      <div className="col-sm-5">
        <PagePreview
          budgetbar={db.get("ranking.budgetbar")}
          shuffleProjects={db.get("ranking.shuffle_projects")}
          nCols={db.get("ranking.n_cols")}
          theme={db.get("ranking.theme")}
          sidebar={db.get("ranking.sidebar")}
          tracker={db.get("ranking.tracker")}
          topTracker={db.get("ranking.top_tracker")}
          showShuffleNote={db.get("ranking.show_shuffle_note")}
        />
        <div className="previewCaption">Preview</div>
      </div>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Project appearance</label>
    <div className="group-body row">
      <div className="col-sm-7">
        <BooleanOption name="ranking.show_cost" db={db} label="Show cost under the description" />
        <BooleanOption name="ranking.show_cost_in_title" db={db} label="Show cost in the title" />
        <BooleanOption name="ranking.show_numbers" db={db} label="Show project numbers" />
        <BooleanOption name="ranking.show_maps" db={db} label="Show maps (for projects that have coordinates)" />
      </div>
      <div className="col-sm-5">
        <ProjectPreview
          showMaps={db.get("ranking.show_maps")}
          showNumbers={db.get("ranking.show_numbers")}
          showCostInTitle={db.get("ranking.show_cost_in_title")}
          showCost={db.get("ranking.show_cost")}
          currencySymbol={db.get("currency_symbol")}
          isToken = {false}
        />
        <div className="previewCaption">Preview</div>
      </div>
    </div>
  </div>

  {/*
  <div className="group">
    <label className="group-title">Has budget limit</label>
    <div className="group-body">
      <BooleanOption name="ranking.has_budget_limit" db={db} label="Has budget limit" />
      <div className="help-block">Is there a limit on the total amount of money the voter can spend?</div>
    </div>
  </div>
  */}

  <div className="group">
    <label className="group-title">Limit on number of projects</label>
    <div className="group-body">
      <BooleanOption name="ranking.has_n_project_limit" db={db} label="Impose a limit on the number of projects the voter can choose" />
      <div className="help-block"></div>

      <Conditional condition={c('ranking.has_n_project_limit')} name="ranking.max_n_projects" db={db}>
        <NumberOption name="ranking.max_n_projects" db={db} />
        { ((value)=>((value >= 1) ? null : (<div className="text-danger">Value must be at least 1.</div>) ))(db.get("ranking.max_n_projects")) }
        <div className="help-block">The maximum number of projects the voter can choose.</div>
      </Conditional>

      <Conditional condition={c('ranking.has_n_project_limit')} name="ranking.min_n_projects" db={db}>
        <NumberOption name="ranking.min_n_projects" db={db} />
        { ((value)=>((value >= 0) ? null : (<div className="text-danger">Value must be at least 0.</div>) ))(db.get("ranking.min_n_projects")) }
        { ((value)=>((value <= c('ranking.max_n_projects')) ? null : (<div className="text-danger">Value must not be greater than the maximum number of projects the voter can choose.</div>) ))(db.get("ranking.min_n_projects")) }
        <div className="help-block">The minimum number of projects the voter must choose.</div>
      </Conditional>
    </div>
  </div>

  <Conditional condition={c('ranking.has_n_project_limit') || c('ranking.has_budget_limit')} name="ranking.allow_selection_beyond_limits" db={db}>
  <div className="group">
    <label className="group-title">Allow selection beyond limits</label>
    <div className="group-body">
      <BooleanOption name="ranking.allow_selection_beyond_limits" db={db} label="While the voter is selecting projects, allow them to exceed the limit(s) temporarily" />
      <div className="help-block">Even if this is enabled, we won't let them submit their vote anyway if it exceeds the limit.</div>
    </div>
  </div>
  </Conditional>

  {/*
  <div className="group">
    <label className="group-title">Project ranking</label>
    <div className="group-body">
      <BooleanOption name="ranking.project_ranking" db={db} label="Make voters rank the projects they choose before submitting their vote" />
    </div>
  </div>
  */}

  {/*
  <Conditional condition={c('ranking.shuffle_projects')} name="ranking.shuffle_probability" db={db}>
    <div className="group">
      <label className="group-title">Shuffle probability</label>
      <div className="group-body">
        <NumberOption name="ranking.shuffle_probability" db={db} />
        <div className="help-block">Probability that the projects are shuffled. Use 1 for "always shuffled." Use 0.5 for "shuffled half of the time."</div>
        { ((value)=>((0 < value && value <= 1) ? null : (<div className="text-danger">Value must be between (0, 1].</div>) ))(db.get("ranking.shuffle_probability")) }
      </div>
    </div>
  </Conditional>
  */}

  <div className="group">
    <label className="group-title">Popup</label>
    <div className="group-body">
      <BooleanOption name="ranking.show_popup" db={db} label="Show a popup (dialog box) when the voter comes to this page" />

      <Conditional condition={c('ranking.show_popup')} db={db}>
        <div className="mt-2">The text in the popup:</div>
        <LocalizedTextOption name="ranking.popup.body" db={db} />
      </Conditional>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Instructions</label>
    <div className="group-body">
      <div>The instructions on how to vote:</div>
      <LocalizedTextOption name="ranking.instructions" db={db} />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="ranking.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Show help</label>
    <div className="group-body">
      <BooleanOption name="ranking.show_help" db={db} label="Show the Help link at the top-right corner" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Checkbox acknowledgment</label>
    <div className="group-body">
      <BooleanOption name="ranking.checkbox_acknowledgment" db={db} label="Before a voter submits their vote, they must click a checkbox that says that they understand that they can't change their vote afterwards" />
    </div>
  </div>

  {/*
  <Conditional condition={c('ranking.sidebar')} name="ranking.allow_select_in_sidebar" db={db}>
    <div className="group">
      <label className="group-title">Allow selection in sidebar</label>
      <div className="group-body">
        <BooleanOption name="ranking.allow_select_in_sidebar" db={db} label="Allow voters to select projects in the project list on the left side of the page" />
      </div>
    </div>
  </Conditional>

  <div className="group">
    <label className="group-title">Reverse order of radio buttons for adjustable cost projects</label>
    <div className="group-body">
      <BooleanOption name="ranking.reverse_order_of_radio_buttons_for_adjustable_cost_projects" db={db} label="Reverse order of radio buttons for adjustable cost projects" />
    </div>
  </div>
  */}

</Conditional>
          </div>


{/*
          <div className="tab-pane" id="thanks_approval-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('thanks_approval') != -1} name="thanks_approval" db={db}>

  <div className="group">
    <label className="group-title">Vote email</label>
    <div className="group-body">
      <BooleanOption name="thanks_approval.vote_email" db={db} label="Show a text field for the voter to optionally enter their email address to receive an email confirming their vote." />
    </div>
  </div>

</Conditional>
          </div>
*/}


          <div className="tab-pane" id="question-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('question') != -1} name="question" db={db}>

  <div className="group">
    <label className="group-title">Question</label>
    <div className="group-body">
      <div className="mt-2">The question to ask the voter:</div>
      <LocalizedTextOption name="question.question" db={db} isHTML={false} />

      <div className="mt-1">The text on the Yes button: (If the voter clicks this button, they go to the next page.)</div>
      <LocalizedTextOption name="question.ok" db={db} isHTML={false} />

      <div className="mt-1">The text on the No button: (If the voter clicks this button, they go to the alternative page, which you must set below.)</div>
      <LocalizedTextOption name="question.alternative" db={db} isHTML={false} />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Alternative page</label>
    <div className="group-body">
      <TextOption name="question.alternative_page" db={db} />
      <div className="help-block">The page to go to if the voter clicks the No button.</div>
    </div>
  </div>

  {/*
  <div className="group">
    <label className="group-title">Alternative params</label>
    <div className="group-body">
      <TextOption name="question.alternative_params" db={db} />
    </div>
  </div>
  */}

</Conditional>
          </div>


          <div className="tab-pane" id="comparison-tab" role="tabpanel">
<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('comparison') != -1} name="comparison" db={db}>

  <div className="group">
    <label className="group-title">Number of pairs</label>
    <div className="group-body">
      <NumberOption name="comparison.n_pairs" db={db} />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Project appearance</label>
    <div className="group-body">
      <BooleanOption name="comparison.show_photos" db={db} label="Show photos" />
      <BooleanOption name="comparison.show_cost_bars" db={db} label="Show cost bars" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Show exit link</label>
    <div className="group-body">
      <BooleanOption name="comparison.show_exit_link" db={db} label="Show the Exit link at the top-right corner to allow voters to skip the comparison voting." />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Research ballot</label>
    <div className="group-body">
      <BooleanOption name="comparison.show_disclaimer" db={db} label="Mark this as a research ballot, and show a disclaimer that says that &quot;This is only a research survey. It will not affect your vote.&quot;" />
    </div>
  </div>

  <div className="group">
    <label className="group-title">Popup</label>
    <div className="group-body">
      <BooleanOption name="comparison.show_popup" db={db} label="Show a popup (dialog box) when the voter comes to this page" />

      <Conditional condition={c('comparison.show_popup')} db={db}>
        <div className="mt-2">The text in the popup:</div>
        <LocalizedTextOption name="comparison.popup.body" db={db} />
      </Conditional>
    </div>
  </div>

</Conditional>
          </div>


          <div className="tab-pane" id="survey-tab" role="tabpanel">

<div className="group">
  <label className="group-title">Survey</label>
  <div className="group-body">
    <WorkflowOption name="workflow" db={db} mode="survey" />
  </div>
</div>

<Conditional condition={flattenedWorkflow && flattenedWorkflow.indexOf('survey') != -1} name="survey" db={db}>

  <div className="group">
    <label className="group-title">Survey URL</label>
    <div className="group-body">
      <TextOption name="survey.url" db={db} />
      { ((value)=>((value.substring(0, 8) == 'https://') ? null : (<div className="text-danger">The URL of the survey website must start with "https://".</div>) ))(db.get("survey.url")) }
      <div className="help-block">
        <p>To protect the voter's privacy, the URL of the survey website <b>must</b> start with "https://", not "http://".</p>
        <p>The survey website <b>must</b> redirect voters to <span className="url">https://pbstanford.org/done_survey{(db.get("default_locale") == "en") ? "" : ("?locale=" + db.get("default_locale"))}</span> after they complete the survey. (See the instructions for <a href="https://www.qualtrics.com/support/survey-platform/survey-module/survey-options/survey-termination/" target="_blank" rel="noopener noreferrer">Qualtrics</a> and <a href="https://help.surveymonkey.com/articles/en_US/kb/What-are-the-Survey-Completion-options" target="_blank" rel="noopener noreferrer">SurveyMonkey</a>.)</p>
      </div>
      <Conditional condition={c('available_locales').length > 1} db={db}>
        <div className="help-block">
          If you want to use different URLs for different languages, leave the text field above blank and enter the URLs below.
        </div>
        <LocalizedTextOption name="survey.url" db={db} showReset={false} isHTML={false} />
      </Conditional>
    </div>
  </div>

  <div className="group">
    <label className="group-title">Ask question</label>
    <div className="group-body">
      <BooleanOption name="survey.asks_question" db={db} label="Ask a question such as &quot;Are you 14 years or older?&quot; before the voter takes the survey. If the voter answers &quot;No&quot;, skip the survey." />

      <Conditional condition={c('survey.asks_question')} db={db}>
        <div className="mt-2">The question to ask the voter:</div>
        <LocalizedTextOption name="survey.question.body" db={db} isHTML={false} />

        <div className="mt-1">The text on the Yes button: (If the voter clicks this button, they take the survey.)</div>
        <LocalizedTextOption name="survey.question.ok" db={db} isHTML={false} />

        <div className="mt-1">The text on the No button: (If the voter clicks this button, they skip the survey.)</div>
        <LocalizedTextOption name="survey.question.alternative" db={db} isHTML={false} />
      </Conditional>
    </div>
  </div>

  {/*
  <div className="group">
    <label className="group-title">Alternative URL</label>
    <div className="group-body">
      <TextOption name="survey.alternative_url" db={db} />
      <div className="help-block">The survey URL if ?alternative=1. This can only be used with the question page.</div>
    </div>
  </div>
  */}

  <div className="group">
    <label className="group-title">Show exit link</label>
    <div className="group-body">
      <BooleanOption name="survey.show_exit_link" db={db} label="Show the Exit link at the top-right corner to allow voters to skip the survey." />
    </div>
  </div>

</Conditional>
          </div>

        </div>

        <div className="modal" id="remoteVoterValidationExplanationModal" tabIndex="-1" role="dialog" aria-labelledby="remoteVoterValidationExplanationModalLabel" aria-hidden="true">
          <div className="modal-dialog" role="document">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title" id="remoteVoterValidationExplanationModalLabel">Remote voter validation methods</h5>
                <button type="button" className="close" data-dismiss="modal" aria-label="Close">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div className="modal-body">
                <ul>
                  <li><b>Remote voting using SMS confirmation</b>: The remote voter enters their phone number. The system sends them a confirmation code through SMS. They enter the confirmation code. The system verifies that it's correct.</li>
                  <li><b>Remote voting using personal information</b>: The remote voter enters their personal information, such as their ID number. The system verifies that it's correct. To use this method, you must import the list of valid ID numbers on the "Codes" page.</li>
                  <li><b>Remote voting using generated codes</b>: The remote voter emails or calls you. You send them an access code. They enter the access code. The system verifies that it's correct.</li>
                  <li><b>Remote voting using free-form text field</b>: The remote voter enters their personal information, such as ZIP code. Then they get to vote. There is <b>no</b> verification. This method is <b>not</b> recommended.</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </React.Fragment>
    );
  }
}
