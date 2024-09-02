-- COMP9311 Assignment 2
-- Written by Cheng_Nie

-- Q1_a: get details of the current Heads of Schools

create or replace view Q1_a(name, school, starting)
as
select P.name, O.longname, A.starting 
from People P, OrgUnits O, Affiliation A, StaffRoles S
where O.id = A.orgUnit and A.role = S.id and P.id = A.Staff and A.ending is NULL and A.isPrimary = 't' 
and O.utype in (select T.id from OrgUnitTypes T where T.name = 'School')
and A.role in (select S.id from StaffRoles S where S.description = 'Head of School');

-- Q1_b: longest-serving and most-recent current Heads of Schools

create or replace view Q1_b(status, name, school, starting)
as
select status, Q1_a.name, Q1_a.school, Q1_a.starting from Q1_a,
(select 
     (case 
       when table1.date_part = table5.maximum_duration then cast('Longest serving' as text)
       when table1.date_part = table6.minimum_duration then cast('Most recent' as text)
       end
     )status , table1.name
  from 
  (select max(table3.date_part) as maximum_duration from 
  (select date_part('day',cast(now() as TIMESTAMP)-cast(Q1_a.starting as TIMESTAMP)) from Q1_a) as table3) as table5,
  (select min(table4.date_part) as minimum_duration from 
  (select date_part('day',cast(now() as TIMESTAMP)-cast(Q1_a.starting as TIMESTAMP)) from Q1_a) as table4) as table6,
  (select date_part('day',cast(now() as TIMESTAMP)-cast(Q1_a.starting as TIMESTAMP)), name from Q1_a) as table1) as table2
  where table2.name = Q1_a.name and table2.status is not NULL 
  order by Q1_a.starting;

-- Q2: the subjects that used the Central Lecture Block the most 

create or replace view Q2(subject_code, use_rate)
as
select Temptable.subject_code, maximum_use as use_rate from 
(select max(Temptable.use_num)::integer as maximum_use from 
(select S.code as subject_code, count(C.id)::integer as use_num
from Subjects S, Classes C, Rooms R, Courses U
where S.id = U.subject and C.course = U.id 
and C.room = R.id and R.id in (select id from Rooms where longname like 'Central Lecture Block%')
and (C.startDate between '2007-01-01' and '2009-12-31') and (C.endDate between '2007-01-01' and '2009-12-31')
group by S.code
order by use_num desc) as Temptable) as Temptable1,
(select S.code as subject_code, count(C.id)::integer as use_num
from Subjects S, Classes C, Rooms R, Courses U
where S.id = U.subject and C.course = U.id 
and C.room = R.id and R.id in (select id from Rooms where longname like 'Central Lecture Block%')
and (C.startDate between '2007-01-01' and '2009-12-31') and (C.endDate between '2007-01-01' and '2009-12-31')
group by S.code
order by use_num desc) as Temptable
where Temptable.use_num = Temptable1.maximum_use
order by Temptable.subject_code
;

-- Q3: all the students who has scored HD no less than 30 time

create or replace view Q3(unsw_id, student_name)
as
select distinct P.unswid, P.name
from People P, CourseEnrolments C
where P.id = C.student and 
C.student in 
(select C.student from CourseEnrolments C where C.grade='HD' group by C.student having count(C.student) > 30)
;

-- Q4: max fail rate

create or replace view Q4(course_id)
as
select course as course_id from 
(select round(fail*1.0/total,3) as failrate, table3.course from 
(select distinct fail, total, CE.course from CourseEnrolments CE, Courses C, Classes CL,
(select count(*) as fail, CE.course FROM CourseEnrolments CE 
where CE.mark is not NULL and CE.mark < 50 
and CE.course in (select CE.course from CourseEnrolments CE where CE.mark is not NULL group by CE.course having count(*) > 50)
GROUP BY CE.course) as table1,
(select count(*) as total, CE.course FROM CourseEnrolments CE 
where CE.mark is not NULL 
and CE.course in (select CE.course from CourseEnrolments CE where CE.mark is not NULL group by CE.course having count(*) > 50)
GROUP BY CE.course) as table2
where table1.course = table2.course and CE.course = table1.course and CE.course = C.id and C.id = CL.course and 
(CL.startDate between '2007-01-01' and '2007-12-31') and (CL.endDate between '2007-01-01' and '2007-12-31')
) as table3
) as table4,
(select max(round(fail*1.0/total,3)) as maximum_failrate from 
(select distinct fail, total, CE.course from CourseEnrolments CE, Courses C, Classes CL,
(select count(*) as fail, CE.course FROM CourseEnrolments CE 
where CE.mark is not NULL and CE.mark < 50 
and CE.course in (select CE.course from CourseEnrolments CE where CE.mark is not NULL group by CE.course having count(*) > 50)
GROUP BY CE.course) as table1,
(select count(*) as total, CE.course FROM CourseEnrolments CE 
where CE.mark is not NULL 
and CE.course in (select CE.course from CourseEnrolments CE where CE.mark is not NULL group by CE.course having count(*) > 50)
GROUP BY CE.course) as table2
where table1.course = table2.course and CE.course = table1.course and CE.course = C.id and C.id = CL.course and 
(CL.startDate between '2007-01-01' and '2007-12-31') and (CL.endDate between '2007-01-01' and '2007-12-31')
) as table3
) as table5
where table4.failrate = table5.maximum_failrate
;

-- Q5: total FTE students per term from 2001 S1 to 2010 S2

create or replace view Q5(term, nstudes, fte)
as
select table3.term,table3.nstudes,table4.fte from 
(select term, count(distinct student) as nstudes from
(select concat(char2_year,lower_sess) as term, uoc, student from 
(select distinct right(cast(T.year as varchar),2) as char2_year, lower(T.sess) as lower_sess, S.uoc, CE.student from Terms T,Subjects S,Courses C, CourseEnrolments CE
where T.id = C.term and S.id = C.subject and C.id = CE.course
and (T.year between 2000 and 2010) and (T.sess = 'S1' or T.sess = 'S2')
order by char2_year) as table1) as table2
group by term order by term) as table3,
(select term, cast(sum(table2.uoc)*1.0/24 as numeric(6,1)) as fte from
(select concat(char2_year,lower_sess) as term, table1.uoc from
(select S.uoc, right(cast(T.year as varchar),2) as char2_year, lower(T.sess) as lower_sess from Terms T, Subjects S,Courses C, CourseEnrolments CE 
where S.id = C.subject and C.id = CE.course and T.id = C.term and (T.year between 2000 and 2010) and (T.sess = 'S1' or T.sess = 'S2')) as table1
) as table2 group by term) as table4
where table3.term = table4.term
;

-- Q6: subjects with > 30 course offerings and no staff recorded

create or replace view Q6(subject, nOfferings)
as
select table4.subject, table4.nOfferings from 
(select distinct S.id as Subject_id ,table1.subject, table2.nOfferings from Subjects S, Courses C,CourseStaff CS,
(select id,code,concat(code,' ',name) as subject from Subjects) as table1,
(select subject, count(subject) as nOfferings from Courses group by subject having count(subject) > 30) as table2
where table1.id = table2.subject and table2.subject = S.id and C.subject = S.id and C.id not in (select course from CourseStaff)) as table4
where table4.Subject_id not in 
(select subject from Courses 
where Courses.id in(select id as CourseID from Courses left join CourseStaff on Courses.id = CourseStaff.course where staff is not null))
;

-- Q7:  which rooms have a given facility

create or replace function
	Q7(text) returns setof FacilityRecord
as $$
  select distinct R.longname as room, F.description as facility from RoomFacilities RF, Rooms R, Facilities F where R.id = RF.room and RF.facility = F.id and F.description ilike concat('%',$1,'%') order by room;
$$ language sql
;

-- Q8: semester containing a particular day

create or replace function Q8(_day date) returns text 
as $$
declare
    term_name    text;
begin
    for term_name in select term from 
    (select id, term, starting, ending, OneWeekBefore_Starting, diff_Starting_Ending,
          (case when diff_Starting_Ending >= 7 then cast(OneWeekBefore_Starting as date) else cast(lag(ending,1) over (order by starting) + interval '1 day' as date) end) as Effective_Starting,
          (case when diff_Starting_Ending < 7 then cast(ending as date) else cast(LEAD(OneWeekBefore_Starting,1) over (order by starting) - interval '1 day' as date) end) as Effective_Ending
      from 
    (select id, term, starting, ending, OneWeekBefore_Starting, abs((LEAD(table2.starting,1) over (order by starting) - table2.ending)) as diff_Starting_Ending from
    (select id, concat(char2_year,lower_sess) as term, starting, ending, (starting - interval '7 day')::date as OneWeekBefore_Starting from 
    (select id, right(cast(year as varchar),2) as char2_year, lower(sess) as lower_sess, starting,ending from Terms) as table1 order by starting) as table2) as table3) as table4
    where $1 between Effective_Starting and Effective_Ending
    loop
       return term_name;
    end loop;
    return term_name;
end;
$$ language plpgsql
;

-- Q9: transcript with variations

create or replace function
	q9(_sid integer) returns setof TranscriptRecord
as $$
declare
    r   TranscriptRecord;
    x integer;
    variation_type VariationType;
    Subject_uoc integer;
    Subject_code char(8);
    Reference_code char(8);
    institution LongName;
    extequiv_number integer;
    UOCVariation integer := 0;
    UOC_All integer := 0 ;
    UOCtotal integer := 0;
    UOCpassed integer := 0;
    wsum integer := 0;
    wam integer := 0;
begin
    select Stu.id into x
    from   Students Stu join People P on (Stu.id = P.id)
    where  P.unswid = _sid;
    if (not found) then
        raise EXCEPTION 'Invalid student %',_sid;
    end if;
      select code into Reference_code from Subjects S join Variations V on (S.id = V.intequiv) join Students Stu on (V.student = Stu.id) join People P on (Stu.id = P.id) where P.unswid = _sid;
      select ES.institution into institution from ExternalSubjects ES join Variations V on (ES.id = V.extequiv) join Students Stu on (V.student = Stu.id) join People P on (Stu.id = P.id) where P.unswid = _sid;
      select S.uoc into Subject_uoc from Subjects S join Variations V on (S.id = V.subject) join Students Stu on (Stu.id = V.student) join People P on (Stu.id = P.id)  where P.unswid = _sid;
	  select extequiv into extequiv_number from ExternalSubjects ES join Variations V on (ES.id = V.extequiv) join Students Stu on (V.student = Stu.id) join People P on (Stu.id = P.id) where P.unswid = _sid;
      select S.code into Subject_code from Subjects S join Variations V on (S.id = V.subject) join Students Stu on (Stu.id = V.student) join People P on (Stu.id = P.id) where P.unswid = _sid;
      select V.vtype into variation_type from Variations V join Students Stu on (Stu.id = V.student) join People P on (Stu.id = P.id) where P.unswid = _sid;
      select sum(S.uoc) into UOCVariation from Subjects S join Variations V on (S.id = V.subject) join Students Stu on (Stu.id = V.student) join People P on (Stu.id = P.id) where P.unswid = _sid;
      for r in select S.code, substr(T.year::text,3,2)||lower(T.sess) as term, S.name, CE.mark, CE.grade, S.uoc from CourseEnrolments CE join Students Stu on (CE.student = Stu.id)
            join People P on (Stu.id = P.id) join Courses C on (CE.course = c.id) join Subjects S on (C.subject = S.id) join Terms T on (C.term = T.id) where P.unswid = _sid order by T.starting, S.code
    loop 
        if (r.grade = 'SY') then
            UOCpassed := UOCpassed + r.uoc;
        elsif (r.mark is not null) then
            if (r.grade in ('PT','PC','PS','CR','DN','HD')) then
                UOCpassed := UOCpassed + r.uoc;
            end if;
            UOCtotal := UOCtotal + r.uoc;
            wsum := wsum + (r.mark * r.uoc);
        end if;
        return next r;
    end loop;
        for Subject_code in select S.code from Subjects S join Variations V on (S.id = V.subject) join Students Stu on (Stu.id = V.student) join People P on (Stu.id = P.id) where P.unswid = _sid
        loop
            if (variation_type = 'advstanding') then
                r := (Subject_code,null,'Advanced standing, based on ...',null,null,Subject_uoc);
                return next r;
                    if (extequiv_number is not null) then
                        r := (null,null,'study at '||institution,null,null,null);
                        return next r;
                    elsif (extequiv_number is null) then
                        r := (null,null,'studying '||Reference_code||' at UNSW',null,null,null);
                        return next r;
                    end if;
            elsif (variation_type = 'substitution') then
                r := (Subject_code,null,'Substitution, based on ...',null,null,null);
                return next r;
                    if (extequiv_number is not null) then
                        r := (null,null,'study at '||institution,null,null,null);
                        return next r;
                    elsif (extequiv_number is null) then
                        r := (null,null,'studying '||Reference_code||' at UNSW',null,null,null);
                        return next r;
                    end if;
            elsif (variation_type = 'exemption') then 
                r := (Subject_code,null,'Exemption, based on ...',null,null,null);
                return next r;
                    if (extequiv_number is not null) then
                        r := (null,null,'study at '||institution,null,null,null);
                        return next r;
                    elsif (extequiv_number is null) then
                        r := (null,null,'studying '||Reference_code||' at UNSW',null,null,null);
                        return next r;
                    end if;
            end if;
        end loop;
    if (UOCtotal = 0) then
        r := (null,null,'No WAM available',null,null,null);
    else
        wam := wsum / UOCtotal;
        UOC_All := UOCpassed + UOCVariation;
        if (variation_type = 'advstanding') then 
            r := (null,null,'Overall WAM',wam,null,UOC_All);
        else
            r := (null,null,'Overall WAM',wam,null,UOCpassed);
        end if;
    end if;
    return next r;
    return;
end;
$$ language plpgsql
;


