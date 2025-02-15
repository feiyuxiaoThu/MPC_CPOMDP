#include "Model.hpp"

namespace MPC_POMDP{

	Model::Model(const size_t s, const size_t a, const size_t o, const double discount):
            S(s), A(a), O(o), discount_(discount), 
            transitions_(A, Matrix2D(S, S)), trans_end_index_(S, Matrix2D(A, S)), 
            rewards_(S, A), observations_(A, Matrix2D(S, O)),
            terminations_(S, true), violations_(S, false), rand_(Seeder::getSeed())
	{
		for (size_t a = 0; a < A; a++)
			transitions_[a].setIdentity();

		rewards_.setZero();

		for (size_t a = 0; a < A; a++) {
			observations_[a].rightCols(O-1).setZero();
			observations_[a].col(0).fill(1.0);
		}

        updateTransEndIndex();

	}

	Model::Model(const Model& model):
			S(model.getS()), A(model.getA()), O(model.getO()), 
            transitions_(A, Matrix2D(S, S)), trans_end_index_(S, Matrix2D(A, S)), 
            rewards_(S, A), observations_(A, Matrix2D(S, O)), 
            terminations_(S, true), violations_(S, false), rand_(Seeder::getSeed())
	{
		setDiscount(model.getDiscount());
		rewards_.setZero();
		for (size_t a = 0; a < A; ++a) {
			for (size_t s = 0; s < S; ++s) {
				//Copy Transition and Reward Matrices
				for (size_t s1 = 0; s1 < S; ++s1) {
					transitions_[a](s, s1) = model.getTransitionProbability(s, a, s1);
					rewards_(s, a) += model.getExpectedReward(s, a, s1) * transitions_[a](s, s1); //This line may not be correct
				}
                if ( !isProbability(S, transitions_[a].row(s)) )
                    throw std::invalid_argument("Input transition matrix does not contain valid probabilities.");
                
                //Copy Observation Matrix
                for (size_t o = 0; o < O; ++o)
                {
 					observations_[a](s, o) = model.getObservationProbability(s, a, o);
                }
				if ( !isProbability(O, observations_[a].row(s)) )
                    throw std::invalid_argument("Input observation matrix does not contain valid probabilities.");
			}
		}
        
        terminations_ = model.getTerminationFunction();
        violations_ = model.getViolationFunction();

        updateTransEndIndex();

	}

    Model::Model(NoCheck, const size_t s, const size_t a, const size_t o, TransitionMatrix && t, 
    	RewardMatrix && r, ObservationMatrix && om, std::vector<bool>& ter, 
        std::vector<bool>& vio, const double d):
    		S(s), A(a), O(o), discount_(d), 
    		transitions_(std::move(t)), trans_end_index_(S, Matrix2D(A, S)), 
            rewards_(std::move(r)), observations_(om), 
            terminations_(ter), violations_(vio), rand_(Seeder::getSeed()) 
    {
        updateTransEndIndex();
    }

    void Model::setTransitionFunction(const TransitionMatrix & t) {
        for ( size_t a = 0; a < A; ++a ) {
            for ( size_t s = 0; s < S; ++s ) {
                if ( t[a].row(s).minCoeff() < 0.0 ||
                     !checkEqualSmall(1.0, t[a].row(s).sum()) )
                {
                    throw std::invalid_argument("Input transition matrix does not contain valid probabilities.");
                }
            }
        }
        
        transitions_ = t;
        updateTransEndIndex();
    }

    void Model::setRewardFunction(const RewardMatrix & r) {
        rewards_ = r;
    }

	void Model::setObservationFunction(const ObservationMatrix & om) {
		for (size_t a = 0; a < A; ++a) {
			for (size_t s = 0; s < S; ++s) {
				if ( !isProbability(O, om[a].row(s)) )
                    throw std::invalid_argument("Input observation matrix does not contain valid probabilities.");
			}
		}

		observations_ = om;
	}

    void Model::setTerminationFunction(const std::vector<bool> & ter) {
        if (ter.size() != S) throw std::invalid_argument("Input termination function does not have the correct size");
        terminations_ = ter;
    }

    void Model::setViolationFunction(const std::vector<bool> & vio) {
        if (vio.size() != S) throw std::invalid_argument("Input violation function does not have the correct size");
        violations_ = vio;
    }

    void Model::setDiscount(const double d) {
        if ( d <= 0.0 || d > 1.0 ) throw std::invalid_argument("Discount parameter must be in (0,1]");
        discount_ = d;
    }

	size_t Model::getS() const { return S; }
	size_t Model::getA() const { return A; }
	size_t Model::getO() const { return O; }
	double Model::getDiscount() const { return discount_; }

	double Model::getTransitionProbability(const size_t s, const size_t a, const size_t s1) const {
		return transitions_[a](s, s1);
	}

	double Model::getExpectedReward(const size_t s, const size_t a, const size_t) const {
		return rewards_(s, a);
	}

    double Model::getObservationProbability(const size_t s1, const size_t a, const size_t o) const {
        return observations_[a](s1, o);
    }

    const Model::TransitionMatrix & Model::getTransitionFunction() const { return transitions_; }
    const Model::TransitionMatrix & Model::getTransitionEndIndex() const { return trans_end_index_; }
    const Model::RewardMatrix &     Model::getRewardFunction()     const { return rewards_; }
    const Model::ObservationMatrix & Model::getObservationFunction() const { return observations_; }
    const std::vector<bool> & Model::getTerminationFunction() const { return terminations_; }
    const std::vector<bool> & Model::getViolationFunction() const { return violations_; }

    const Matrix2D & Model::getTransitionFunction(const size_t a) const { return transitions_[a]; }
    const Matrix2D & Model::getTransitionEndIndex(const size_t s1) const { return trans_end_index_[s1]; }
    const Matrix2D & Model::getObservationFunction(const size_t a) const { return observations_[a]; }

    std::tuple<size_t,size_t, double> Model::propagateSOR(const size_t s, const size_t a) const {
        const size_t s1 = sampleProbability(S, transitions_[a].row(s), rand_);
        const double r = rewards_(s, a);
        const auto o = sampleProbability(O, observations_[a].row(s1), rand_);
        return std::make_tuple(s1, o, r);
    }

    bool Model::isTermination(const size_t s) const { return terminations_[s]; }
    bool Model::isViolation(const size_t s) const { return violations_[s]; }

    void Model::updateTransEndIndex() {
        for ( size_t s = 0; s < S; ++s )
            for ( size_t a = 0; a < A; ++a )
                for ( size_t s1 = 0; s1 < S; ++s1 )
                    trans_end_index_[s1](a, s) = transitions_[a](s, s1);
    }
}