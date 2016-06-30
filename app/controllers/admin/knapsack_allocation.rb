class KnapsackAllocation
  # Takes the project_costs and budget, and does a knapsack allocation
  # project_costs should be a hash table, where the keys are project ids, and the values are the lists of the amounts that have been allocated by voters to this project. Zero amounts don't need to be reported but are harmless if reported
  # An example of project_costs: {1=>[10, 12, 12, 15, 11], 2=>[10, 10, 9, 8, 12, 15], 3=>[5, 10, 15, 20]}
  # It also takes a function optinially to allocate money to projects once there is a tie among several project_chunks. The default allocates in increasing order of chunk sizes.

  # After creating an instance, the total allocation can be accessed using the method total_allocations
  attr_reader :total_allocations

  # Other accessor methods
  attr_reader :chunks
  attr_reader :budget
  attr_reader :discrete_allocations
  attr_reader :partial_allocations
  attr_reader :accumulated_budget

  # The main function that does all the computation
  def initialize(project_costs, budget, partial_allocation_method = method(:increasing_partial_allocation))
    @budget = budget
    chunks = []
    # For any project, chunk it into discrete pieces such that each piece is the difference of two subsequent values that occur in the project_costs for that project. For each chunk, associate it with the number of users who voted for that chunk
    project_costs.keys.each do |project_id|
      chunks += chunk_project_votes(project_costs[project_id], project_id)
    end
    # Now, transform it so that chunks are arranged by the number of votes received
    @chunks = chunks
      .group_by { |vote| vote[2] }
      .sort { |x, y| y[0] <=> x[0] }
    # Now allocate funds to projects in decreasing order of votes received
    @discrete_allocations = Hash.new(0)
    @accumulated_budget = 0
    continue_flag = true
    i = 0
    n = @chunks.length
    @partial_allocations = Hash.new(0)
    while i < n and continue_flag do
      next_chunks = @chunks[i][1]
      next_cost = next_chunks.map { |chunk| chunk[1] }.sum
      if next_cost + @accumulated_budget > budget
        continue_flag = false
        partially_allocated_chunks = next_chunks.map{ |chunk| [chunk[0], chunk[1]] }
        partial_allocation_method.call(partially_allocated_chunks, budget-accumulated_budget)
          .each{|x| @partial_allocations[x[0]] += x[1]}
      else
        @accumulated_budget += next_cost
        next_chunks.each { |chunk| @discrete_allocations[chunk[0]] += chunk[1] }
      end
      i += 1
    end
    @total_allocations = Hash.new(0)
    (@partial_allocations.keys | @discrete_allocations.keys).map do |project_id|
      @total_allocations[project_id] = @partial_allocations[project_id] + @discrete_allocations[project_id]
    end
  end

  def chunk_project_votes(costs, project_id)
    # Assume that costs is a list of all the chosen costs in the votes cast for this project
    # Returns project_chunks, a list, with each element being of the type [project_id, cost_chunk, votes]
    prev = 0
    n = costs.length
    i = 0
    project_chunks = []
    costs.sort.each do |cost|
      if cost != prev
        chunk = cost - prev
        prev = cost
        project_chunks << [project_id, chunk, n - i]
      end
      i += 1
    end
    project_chunks
  end

  # A partial allocation method for residual budget where the projects are satisfied proportionally
  def fractional_partial_allocation(chunks, budget)
    cost = chunks.map {|chunk| chunk[1]}.sum
    fraction = budget.to_f / cost
    chunks.map { |chunk| [chunk[0], chunk[1] * fraction] }
  end

  # A partial allocation method for residual budget where the projects are satisfied in inreasing cost
  def increasing_partial_allocation(chunks, budget)
    assigned_cost = 0
    chunks.sort { |x, y| x[1] <=> y[1] }.map do |chunk|
      if assigned_cost < budget
        cost = chunk[1]
        if cost > budget - assigned_cost
          cost = budget - assigned_cost
        end
        assigned_cost += cost
        [chunk[0], cost]
      end
    end.compact
  end
end
