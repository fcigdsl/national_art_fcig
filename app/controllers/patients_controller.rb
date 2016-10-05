class PatientsController < GenericPatientsController
  
  def exitcare_dashboard
    @patient = Patient.find(params[:id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
	@exit_states = concept_set("EXIT FROM CARE").flatten.uniq!
    render :template => 'dashboards/exitcare_dashboard.rhtml', :layout => false
  end

  def exitcare
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
      render :template => 'dashboards/exitcare_tab', :layout => false
  end
  def exitcare_history
    @patient = Patient.find(params[:patient_id])
    encounter_type = EncounterType.find_by_name("EXIT FROM HIV CARE").id

    @encounters = Encounter.find(:all,  
                  :conditions => [" patient_id = ? AND encounter_type = ?", 
                                  @patient.id, encounter_type]) 
    @creator_name = {}
    @encounters.each do |encounter|
      id = encounter.creator
      user_name = User.find(id).person.names.first
      @creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
  
    render :template => 'dashboards/exitcare_tab', :layout => false
  end

  def patient_transfer_out_label(patient_id)
    date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    
    who_stage = demographics.reason_for_art_eligibility 
    initial_staging_conditions = demographics.who_clinical_conditions.split(';')
    destination = demographics.transferred_out_to
   
    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
   
    # 25, 30
    # Patient personanl data 
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("To #{destination}", {:font_reverse => false}) unless destination.blank?
    label.draw_multi_text("ARV number: #{demographics.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{demographics.name} (#{demographics.sex.first})\nAge: #{demographics.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    art_start_date = PatientService.date_antiretrovirals_started(patient).strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Diagnosis", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{who_stage}", {:font_reverse => false})
    label.draw_multi_text("ART start date: #{art_start_date}",{:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})
# !!!! TODO
    staging_conditions = ""
    count = 1
    initial_staging_conditions.each{|condition|
     if staging_conditions.blank?
       staging_conditions = "(#{count}) #{condition}" unless condition.blank?
     else
       staging_conditions+= " (#{count+=1}) #{condition}" unless condition.blank?
     end
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

    # Print information on current status of the patient transfering out!
    init_ht = "Init HT: #{demographics.init_ht}"                    
    init_wt = "Init WT: #{demographics.init_wt}"

    first_cd4_count = "CD count " + demographics.cd4_count if demographics.cd4_count
    unless demographics.cd4_count_date.blank?
      first_cd4_count_date = "CD count date #{demographics.cd4_count_date.strftime('%d-%b-%Y')}"
    end
    # renamed current status to Initial height/weight as per minimum requirements
    label.draw_multi_text("Initial Height/Weight", {:font_reverse => true})
    label.draw_multi_text("#{init_ht} #{init_wt}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count_date}", {:font_reverse => false})
 
    # Print information on current treatment of the patient transfering out!

    demographics.reg = []

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    previous_orders = Order.find(:all, :select => "obs.obs_datetime, drug_order.drug_inventory_id", :joins =>"INNER JOIN obs ON obs.order_id = orders.order_id LEFT JOIN drug_order ON orders.order_id = drug_order.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?                    
        	AND obs_datetime <=?",
        	patient.id, concept_id, date.strftime('%Y-%m-%d 23:59:59')],
        :order => "obs_datetime DESC")

	previous_date = nil
	drugs = []

	finished = false

    previous_orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
      	next unless MedicationService.arv(drug)
		next if finished

		if previous_date.blank?
			previous_date = order.obs_datetime.to_date
		end
		if previous_date == order.obs_datetime.to_date 
			demographics.reg << (drug.concept.shortname || drug.concept.fullname)
			previous_date = order.obs_datetime.to_date
		else
			if !drugs.blank?
				finished = true
			end
		end
    end

	demographics.reg = demographics.reg.uniq.join(" + ")

    label.draw_multi_text("Current ART drugs", {:font_reverse => true})
    label.draw_multi_text("#{demographics.reg}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.find(session[:location_id]).name.match(/outpatient/i)

    unless result
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.upcase == "REGISTRATION"
        next if encounter.name.upcase == "HIV REGISTRATION"
        next if encounter.name.upcase == "HIV STAGING"
        next if encounter.name.upcase == "HIV CLINIC CONSULTATION"
        next if encounter.name.upcase == "VITALS"
        next if encounter.name.upcase == "ART ADHERENCE"
        encounter.to_s.split("<b>").each do |string|
          concept_name = string.split("</b>:")[0].strip rescue nil
          obs_value = string.split("</b>:")[1].strip rescue nil
          next if string.match(/Workstation location/i)
          next if obs_value.blank?
          label.draw_multi_text("#{encounter.name.humanize} - #{concept_name}: #{obs_value}", :font_reverse => false)
        end
      }
      label.print(1)
    end
  end

  def mastercard_visit_label(patient, date = Date.today)
  	patient_bean = PatientService.get_patient(patient.person)
    visit = visits(patient, date)[date] rescue {}

    return if visit.blank? 
    visit_data = mastercard_visit_data(visit)
    arv_number = patient_bean.arv_number || patient_bean.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient_bean.name}(#{patient_bean.sex})",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given") 
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(2)
  end

  # Experimental alerts from FCIG encoded guidelines - ym
  def alerts(patient, session_date = Date.today) 
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due
	patient_bean = PatientService.get_patient(patient.person)
    alerts = []

    type = EncounterType.find_by_name("APPOINTMENT")
    
    @show_change_app_date = Observation.find(:first,                          
    :order => "encounter_datetime DESC,encounter.date_created DESC",          
    :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
    :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
    AND encounter_datetime >= ? AND encounter_datetime <= ?",
    ConceptName.find_by_name('Appointment date').concept_id,                  
    type.id, patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),
    session_date.strftime("%Y-%m-%d 23:59:59")]) != nil                    

    next_appt = Observation.find(:first,:order => "encounter_datetime DESC,encounter.date_created DESC",
               :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
               :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
               AND obs_datetime <= ?",ConceptName.find_by_name('Appointment date').concept_id,
               type.id,patient.id,session_date.strftime("%Y-%m-%d 23:59:59")
               ]).value_datetime.strftime("%a %d %B %Y") rescue nil
    alerts << ('Next appointment: ' + next_appt) unless next_appt.blank?

    encounter_dates = Encounter.find_by_sql("SELECT * FROM encounter WHERE patient_id = #{patient.id} AND encounter_type IN (" +
        ("SELECT encounter_type_id FROM encounter_type WHERE name IN ('VITALS', 'TREATMENT', " +
          "'HIV RECEPTION', 'HIV STAGING', 'HIV CLINIC CONSULTATION', 'DISPENSING')") + ")").collect{|e|
      e.encounter_datetime.strftime("%Y-%m-%d")
    }.uniq

    missed_appt = patient.encounters.find_last_by_encounter_type(type.id, 
      :conditions => ["NOT (DATE_FORMAT(encounter_datetime, '%Y-%m-%d') IN (?)) AND encounter_datetime < NOW()",
        encounter_dates], :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Missed ' + missed_appt).capitalize unless missed_appt.blank?

    @adherence_level = ConceptName.find_by_name('What was the patients adherence for this drug order').concept_id
    type = EncounterType.find_by_name("ART ADHERENCE")

    observations = Observation.find(:all,:joins =>"INNER JOIN encounter e USING(encounter_id)",
      :conditions =>["concept_id = ? AND encounter_type = ? AND patient_id = ? AND 
      encounter_datetime >= ? AND encounter_datetime <= ?",@adherence_level,type,
      patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")],
      :order => "obs_datetime DESC")

    (observations || []).map do |adh|
      adherence = adh.value_numeric ||= adh.value_text
      if (adherence.to_f >= 95 || adherence.to_f <= 105)
        drug_name = adh.order.drug_order.drug.concept.shortname rescue adh.order.drug_order.drug.name
        alerts << "Adherence: #{drug_name} (#{adh.value_numeric}%)"
      end
		
    end 

    type = EncounterType.find_by_name("DISPENSING")
    patient.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.each do | obs |
      next if obs.order.blank?
      next if obs.order.auto_expire_date.blank?
      alerts << "Drugs runout date: #{obs.order.drug_order.drug.name} #{obs.order.auto_expire_date.to_date.strftime('%d-%b-%Y')}"
    end rescue []

    # BMI alerts
    if patient_bean.age >= 15
      bmi_alert = current_bmi_alert(PatientService.get_patient_attribute_value(patient, "current_weight"), PatientService.get_patient_attribute_value(patient, "current_height"))
      alerts << bmi_alert if bmi_alert
    end
    
    program_id = Program.find_by_name("HIV PROGRAM").id
    location_id = Location.current_health_center.location_id

    patient_hiv_program = PatientProgram.find(:all,:conditions =>["voided = 0 AND patient_id = ? AND program_id = ? AND location_id = ?", patient.id , program_id, location_id])

    hiv_status = PatientService.patient_hiv_status(patient)
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.strip}" == 'Negative' && PatientService.months_since_last_hiv_test(patient.id) > 3)
    #alerts << "Patient not on ART" if (("#{hiv_status.strip}" == 'Positive') && !patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) ||
                                                          ((patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) && (ProgramWorkflowState.find_state(patient_hiv_program.last.patient_states.last.state).concept.fullname == "Pre-ART (Continue)"))
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.strip}" == 'Unknown'
    alerts << "Lab: Expecting submission of sputum" unless PatientService.sputum_orders_without_submission(patient.id).empty?
    alerts << "Lab: Waiting for sputum results" if PatientService.recent_sputum_results(patient.id).empty? && !PatientService.recent_sputum_submissions(patient.id).empty?
    alerts << "Lab: Results not given to patient" if !PatientService.recent_sputum_results(patient.id).empty? && given_sputum_results(patient.id).to_s != "Yes"
    alerts << "Patient go for CD4 count testing" if cd4_count_datetime(patient) == true
    alerts << "Lab: Patient must order sputum test" if patient_need_sputum_test?(patient.id)
    alerts << "Refer to ART wing" if show_alert_refer_to_ART_wing(patient)

    actions = DeterminingArtEligibility.guideline_recommendations(patient_bean)
    guideline_alerts = []
	actions.each do | action |
		action_verb = action[0] 
		verb_complement = action[1]

		if action_verb == 'Eligible for therapy'
			guideline_alerts << ('Patient is eligible for ' + verb_complement + ' (' + action[2] + ')').gsub('hiv', 'HIV')
		else
			guideline_alerts << action_verb + ' ' + verb_complement
		end
	end

	alerts = alerts + guideline_alerts.uniq 

    alerts
  end


end
