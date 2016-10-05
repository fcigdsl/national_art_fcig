module CoreService
	def self.get_global_property_value(global_property)
		property_value = Settings[global_property] 
		if property_value.nil?
			property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
													).property_value rescue nil
		end
		return property_value
	end

	def self.concept_set(concept_name)
		concept_id = ConceptName.find_by_name(concept_name).concept_id rescue nil
		
		return_value = nil
		
		if !concept_id.nil?
			set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
			options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname] }
			return_value = options
			if return_value.empty?
				return_value = nil
			end
		end

		return return_value
	end

end
	
