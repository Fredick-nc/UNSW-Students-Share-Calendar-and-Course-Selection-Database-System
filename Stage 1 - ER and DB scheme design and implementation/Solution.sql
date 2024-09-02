-- COMP9311 Assignment 1 Schema
--
-- Written by: Cheng Nie, 11/10/22 

-- Domains

-- Calendar access levels

create domain AccessLevel as text
	check (value in ('no-access','blocks-only','read-only','read-write'));

-- Email addresses are strings with a particular structure
-- * this regexp is approximate, but adequate for this assignment
-- * search on Google for "regular expression email address" for others
-- * \w represents that character class containing alphanumerics + underscore

create domain EmailAddress as text
	check (value ~ E'[a-zA-Z][\\w.-]*[\\w]?@[a-zA-Z][\\w-]*(\\.[a-zA-Z][\\w-]*)*');

-- Tables

create table People (
    Email EmailAddress PRIMARY KEY,
  	Name VARCHAR(50) NOT NULL
);

create table Users (
	Email EmailAddress PRIMARY KEY,
	Username VARCHAR(25) NOT NULL UNIQUE,
	Password VARCHAR(25) NOT NULL,
	UNSWid CHAR(8) NOT NULL UNIQUE,
	isActive BOOLEAN NOT NULL,
	foreign key(Email) references People(Email)
);

create table Groups (
	GroupID SERIAL PRIMARY KEY,
	Name VARCHAR(25) NOT NULL,
	Email EmailAddress NOT NULL UNIQUE,
	foreign key(Email) references Users(Email)
);

create table Calendars (
	CalenID SERIAL PRIMARY KEY,
	Name VARCHAR(25) NOT NULL,
	DefaultAccess AccessLevel DEFAULT 'no-access',
	Email EmailAddress NOT NULL UNIQUE,
	foreign key(Email) references Users(Email)
);

create table Events (
	eventID SERIAL PRIMARY KEY,
	Title VARCHAR(25) NOT NULL,
	Location VARCHAR(25),
	notes VARCHAR(255),
	TimeOrientedEventsType CHAR(20) NOT NULL
	CONSTRAINT TimeOrientedEventsValue check (TimeOrientedEventsType in ('OneDayEvents','DeadlineEvents','TimeslotEvents')),
	DateOrientedEventsType CHAR(20) NOT NULL
	CONSTRAINT DateOrientedEventsValue check (DateOrientedEventsType in ('OneoffEvents','TimespanEvents')),
	startTime TIME NOT NULL check(TimeOrientedEventsType='TimeslotEvents'),
	endTime TIME NOT NULL check(TimeOrientedEventsType='TimeslotEvents' or TimeOrientedEventsType='DeadlineEvents'),
	onDate DATE NOT NULL check(DateOrientedEventsType='OneoffEvents'),
	startDate DATE NOT NULL check(DateOrientedEventsType='TimespanEvents'),
	endDate DATE NOT NULL check(DateOrientedEventsType='TimespanEvents'),
	IsRecurringEvents CHAR(3) NOT NULL
	CONSTRAINT IsRecurringEventsValue check (IsRecurringEvents in ('Yes','No')),
	frequency VARCHAR(20) NOT NULL check(IsRecurringEvents='Yes'),
	DayOfWk CHAR(3) NOT NULL
	CONSTRAINT DayOfWkValue check (DayOfWk in ('Mon','Tue','Wed','Thu','Fri','Sat','Sun') and IsRecurringEvents='Yes'),
	DayOfMon INT NOT NULL
	CONSTRAINT DayOfMonValue check (DayOfMon in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31) and IsRecurringEvents='Yes'),
	Month CHAR(3) NOT NULL
	CONSTRAINT MonthValue check (Month in ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec') and IsRecurringEvents='Yes'),
	CalenID SERIAL NOT NULL UNIQUE,
	Email EmailAddress NOT NULL UNIQUE,
	foreign key(CalenID) references Calendars(CalenID),
	foreign key(Email) references Users(Email)
);

create table eventsAlarms (
	eventID SERIAL PRIMARY KEY,
	alarms INTERVAL NOT NULL, 
	UNSWid CHAR(8) UNIQUE,
	isActive BOOLEAN NOT NULL,
	SendEmail BOOLEAN DEFAULT TRUE check((alarms >= '1h' and UNSWid = NULL) or (alarms > '30m' and UNSWid != NULL)),
	DoNothing BOOLEAN DEFAULT TRUE check(alarms < '1h' and UNSWid = NULL),
	PopUpAlert BOOLEAN DEFAULT TRUE check(alarms <= '30m' and isActive = TRUE),
	foreign key(eventID) references Events(eventID)
); 

create table RecurringEventsExceptions (
	eventID SERIAL PRIMARY KEY,
	exceptions DATE NOT NULL,
	foreign key(eventID) references Events(eventID)
); 

create table UsersAccessToCalendars (
	Email EmailAddress NOT NULL,
	CalenID SERIAL NOT NULL,
	AccessLevel AccessLevel NOT NULL,
	PRIMARY KEY(Email,CalenID),
	foreign key(Email) references Users(Email),
	foreign key(CalenID) references Calendars(CalenID)
); 

create table UsersVisibleToCalendars (
	Email EmailAddress NOT NULL,
	CalenID SERIAL NOT NULL,
	isActive BOOLEAN check(isActive in (TRUE)),
	AccessLevel AccessLevel NOT NULL,
	Checkboxes CHAR(10) DEFAULT NULL
	CONSTRAINT VisibilityValue check (Checkboxes in ('Public','Private') and (AccessLevel in ('read-only','read-write'))),
	Title VARCHAR(25) DEFAULT NULL
	CONSTRAINT EventsVisibility check (Checkboxes in ('Public')),
	PRIMARY KEY(Email,CalenID),
	foreign key(Email) references Users(Email),
	foreign key(CalenID) references Calendars(CalenID)
); 

create table CalendarsAccessToGroups (
	CalenID SERIAL NOT NULL,
	GroupID SERIAL NOT NULL,
	AccessLevel AccessLevel NOT NULL,
	PRIMARY KEY(CalenID,GroupID),
	foreign key(CalenID) references Calendars(CalenID),
	foreign key(GroupID) references Groups(GroupID)
); 

create table PeopleMemberOfGroups(
	GroupID SERIAL NOT NULL,
	Email EmailAddress NOT NULL, 
	PRIMARY KEY(GroupID,Email),
	foreign key(GroupID) references Groups(GroupID),
	foreign key(Email) references People(Email)
); 

create table PeopleInvitedToEvents (
	eventID SERIAL NOT NULL,
	Email EmailAddress NOT NULL,
	RSVP CHAR(5) NOT NULL
	CONSTRAINT RSVPValue check (RSVP in ('Yes','No','NULL')),
	PRIMARY KEY(eventID,Email),
	foreign key(eventID) references Events(eventID),
	foreign key(Email) references People(Email)
); 