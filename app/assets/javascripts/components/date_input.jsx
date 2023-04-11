const displayDateRegex = /^ *(0?[1-9]|1[012]) *\/ *(0?[1-9]|[1-2][0-9]|30|31) *\/ *(\d{4}) *$/; // Regular expression for MM/DD/YYYY dates.
const internalDateRegex = /^(\d{4})-(0?[1-9]|1[012])-(0?[1-9]|[1-2][0-9]|30|31)(T([0-9:+Z]+)?)?$/; // Regular expression for YYYY-MM-DD dates.

class DateInput extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      valid: true
    };
    this.handleChange = this.handleChange.bind(this);
  }

  handleChange(day, modifiers, dayPickerInput) {
    const input = dayPickerInput.getInput();
    const isEmpty = input.value.trim().length == 0;
    this.props.onChange((day !== undefined) ? this.formatInternalDate(day) : "");
    this.setState({valid: day !== undefined || isEmpty});
  }

  parseDisplayDate(s) {
    // Parse MM/DD/YYYY as a date object.
    const m = displayDateRegex.exec(s);
    if (m === null)
      return undefined;
    return new Date(m[3], m[1] - 1, m[2]);
  };

  formatDisplayDate(date) {
    // Format a date object as MM/DD/YYYY.
    return (date.getMonth() + 1) + "/" + date.getDate() + "/" + date.getFullYear();
  };

  parseInternalDate(s) {
    // Parse YYYY-MM-DD as a date object.
    if (!s)
      return undefined;
    const m = internalDateRegex.exec(s);
    if (m === null)
      return undefined;
    return new Date(m[1], m[2] - 1, m[3]);
  };

  formatInternalDate(date) {
    const to2Digits = (x) => ((x == "") ? "" : ("0" + x).slice(-2));
    return date.getFullYear() + "-" + to2Digits(date.getMonth() + 1) + "-" + to2Digits(date.getDate());
  }

  render() {
    return (
      <DayPicker.Input parseDate={this.parseDisplayDate} formatDate={this.formatDisplayDate} onDayChange={this.handleChange} placeholder="MM/DD/YYYY" inputProps={{className: "form-control" + (this.state.valid ? "" : " is-invalid")}} value={this.parseInternalDate(this.props.value)} />
    );
  }
}


/*
class DateInput extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      year: "",
      month: "",
      day: "",
      hour: 12,
      minute: 0,
      ampm: "AM"
    };

    this.handleYearChange = (event) => { this.setState({year: +event.target.value}); };
    this.handleMonthChange = (event) => { this.setState({month: +event.target.value}); };
    this.handleDayChange = (event) => { this.setState({day: +event.target.value}); };
    this.handleHourChange = (event) => { this.setState({hour: +event.target.value}); };
    this.handleMinuteChange = (event) => { this.setState({minute: +event.target.value}); };
    this.handleAMPMChange = (event) => { this.setState({ampm: event.target.value}); };

    this.handleChange = this.handleChange.bind(this);

    this.months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  }

  shouldComponentUpdate(nextProps) { // FIXME: Likely wrong.
    return false;
  }

  handleChange(day) {
    if (!day) // In that case, handleInputChange will be called.
      return;
    this.props.db.set(this.props.name, formatDate(day));
  }

  render() {
    const dayOptions = [];
    for (let i = 1; i <= 31; ++i) {
      dayOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const yearOptions = [];
    const currentYear = (new Date()).getFullYear();
    for (let i = currentYear - 4; i <= currentYear + 10; ++i) {
      yearOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const hourOptions = [];
    for (let i = 1; i <= 12; ++i) {
      hourOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const minuteOptions = [];
    for (let i = 0; i < 60; i += 5) {
      minuteOptions.push(<option key={i} value={i}>{("0" + i).slice(-2)}</option>);
    }
    return (
      <React.Fragment>
        <select className="form-control" value={this.state.month} onChange={this.handleMonthChange}>
          <option value=""></option>
          {this.months.map((month, index) => (
            <option key={index} value={index}>{month}</option>
          ))}
        </select>
        &nbsp;
        <select className="form-control" value={this.state.day} onChange={this.handleDayChange}>
          <option value=""></option>
          {dayOptions}
        </select>
        &nbsp;
        <select className="form-control" value={this.state.year} onChange={this.handleYearChange}>
          <option value=""></option>
          {yearOptions}
        </select>
        &nbsp; &nbsp;
        <select className="form-control" value={this.state.hour} onChange={this.handleHourChange}>
          <option value=""></option>
          {hourOptions}
        </select>
        :
        <select className="form-control" value={this.state.minute} onChange={this.handleMinuteChange}>
          <option value=""></option>
          {minuteOptions}
        </select>
        &nbsp;
        <select className="form-control" value={this.state.ampm} onChange={this.handleAMPMChange}>
          <option value=""></option>
          <option value="AM">AM</option>
          <option value="PM">PM</option>
        </select>
      </React.Fragment>
    );
  }
}
*/

/*
class DateInput extends React.Component {
  constructor(props) {
    super(props);

    const blah = (name) => {
      return (event) => {
        const o = this.parseDate(this.props.value);
        o[name] = event.target.value;
        props.onChange( this.formateDate(o) );
      };
    };

    this.handleYearChange = blah("year");
    this.handleMonthChange = blah("month");
    this.handleDayChange = blah("day");
    this.handleHourChange = blah("hour");
    this.handleMinuteChange = blah("minute");
    this.handleAMPMChange = blah("ampm");

    this.months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  }

  parseDate(s) {
    // Parse ISO 8601 dates like 2018-06-26T16:45
    const toInt = (x) => {
      const y = parseInt(x, 10);
      return (isNaN(y) || x === "") ? "" : y;
    };
    const o = {
      year: "",
      month: "",
      day: "",
      hour: 12,
      minute: 0,
      ampm: "AM"
    };
    if (!s)
      return o;
    const a = s.split("T");
    const dateComps = a[0].split("-");
    if (dateComps.length == 3) {
      o.year = toInt(dateComps[0]);
      o.month = toInt(dateComps[1]);
      o.day = toInt(dateComps[2]);
    }
    if (a.length == 2) {
      const timeComps = a[1].split(":");
      const hour = toInt(timeComps[0]);
      if (hour !== "") {
        const tmp = hour % 12;
        o.hour = (tmp == 0) ? 12 : tmp;
        o.ampm = (hour < 12) ? "AM" : "PM";
      }
      o.minute = toInt(timeComps[1]);
    }
    return o;
  }

  formateDate(o) {
    const to2Digits = (x) => ((x == "") ? "" : ("0" + x).slice(-2));
    const hour = ((o.hour | 0) % 12) + ((o.ampm == "PM") ? 12 : 0);
    const tmp =  o.year + "-" + to2Digits(o.month) + "-" + to2Digits(o.day) + "T" + to2Digits(hour) + ":" + to2Digits(o.minute);
    
    return tmp;
  }

  render() {
    const o = this.parseDate(this.props.value);
    

    const dayOptions = [];
    for (let i = 1; i <= 31; ++i) {
      dayOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const yearOptions = [];
    const currentYear = (new Date()).getFullYear();
    for (let i = 2015; i <= currentYear + 10; ++i) {
      yearOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const hourOptions = [];
    for (let i = 1; i <= 12; ++i) {
      hourOptions.push(<option key={i} value={i}>{i}</option>);
    }

    const minuteOptions = [];
    for (let i = 0; i < 60; i += 5) {
      minuteOptions.push(<option key={i} value={i}>{("0" + i).slice(-2)}</option>);
    }
    return (
      <React.Fragment>
        <select className="form-control" value={o.month} onChange={this.handleMonthChange}>
          <option value=""></option>
          {this.months.map((month, index) => (
            <option key={index} value={index + 1}>{month}</option>
          ))}
        </select>
        &nbsp;
        <select className="form-control" value={o.day} onChange={this.handleDayChange}>
          <option value=""></option>
          {dayOptions}
        </select>
        &nbsp;
        <select className="form-control" value={o.year} onChange={this.handleYearChange}>
          <option value=""></option>
          {yearOptions}
        </select>
        &nbsp; &nbsp;
        <select className="form-control" value={o.hour} onChange={this.handleHourChange}>
          {hourOptions}
        </select>
        :
        <select className="form-control" value={o.minute} onChange={this.handleMinuteChange}>
          {minuteOptions}
        </select>
        &nbsp;
        <select className="form-control" value={o.ampm} onChange={this.handleAMPMChange}>
          <option value="AM">AM</option>
          <option value="PM">PM</option>
        </select>
      </React.Fragment>
    );
  }
}
*/
